using System.Buffers.Text;
using System.Text;
using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Swipes;
using In2U.Api.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace In2U.Api.Services;

public sealed class SwipeService : ISwipeService
{
    private readonly AppDbContext _db;
    private readonly IMatchService _matches;
    private readonly GeoOptions _geo;

    public SwipeService(
        AppDbContext db,
        IMatchService matches,
        IOptions<GeoOptions> geoOpts)
    {
        _db = db;
        _matches = matches;
        _geo = geoOpts.Value;
    }

    public async Task<SwipeResponse> RecordAsync(
        long fromUserId, Guid toUserGuid, Guid venueGuid, SwipeDirection direction, CancellationToken ct = default)
    {
        var venue = await _db.Venues
            .Where(v => v.VenueGuid == venueGuid && v.Status == VenueStatus.Active)
            .Select(v => new { v.Id })
            .FirstOrDefaultAsync(ct);
        if (venue is null) return new SwipeResponse(false, null);

        var toUser = await _db.Users
            .Where(u => u.UserGuid == toUserGuid && !u.IsDeleted)
            .Select(u => new { u.Id })
            .FirstOrDefaultAsync(ct);

        if (toUser is null)
        {
            // Ambient target path: persist silently, never invoke matching.
            var ambientProfileId = await _db.AmbientProfiles
                .Where(a => a.AmbientProfileGuid == toUserGuid && a.Active)
                .Select(a => (long?)a.Id)
                .FirstOrDefaultAsync(ct);
            if (ambientProfileId is null) return new SwipeResponse(false, null);

            var ambientSwipe = new AmbientSwipe
            {
                FromUserId = fromUserId,
                AmbientProfileId = ambientProfileId.Value,
                VenueId = venue.Id,
                Direction = direction,
                CreatedAt = DateTime.UtcNow,
            };
            _db.AmbientSwipes.Add(ambientSwipe);
            try
            {
                await _db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                _db.Entry(ambientSwipe).State = EntityState.Detached;
                // Idempotent: first ambient swipe wins.
            }
            return new SwipeResponse(false, null);
        }

        if (toUser.Id == fromUserId) return new SwipeResponse(false, null);

        var bothActive = await _db.VenueMemberships
            .Where(m => m.VenueId == venue.Id
                        && (m.UserId == fromUserId || m.UserId == toUser.Id))
            .Select(m => m.UserId)
            .Distinct()
            .CountAsync(ct);
        if (bothActive < 2) return new SwipeResponse(false, null);

        var swipe = new Swipe
        {
            FromUserId = fromUserId,
            ToUserId = toUser.Id,
            VenueId = venue.Id,
            Direction = direction,
            TargetKind = TargetKind.RealUser,
            CreatedAt = DateTime.UtcNow,
        };
        _db.Swipes.Add(swipe);
        try
        {
            await _db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            _db.Entry(swipe).State = EntityState.Detached;
            // Idempotent: first swipe wins. Re-read existing direction.
            var existing = await _db.Swipes.FirstOrDefaultAsync(s =>
                s.FromUserId == fromUserId && s.ToUserId == toUser.Id && s.VenueId == venue.Id, ct);
            if (existing is null) return new SwipeResponse(false, null);
            direction = existing.Direction;
        }

        if (direction != SwipeDirection.Right) return new SwipeResponse(false, null);

        var dto = await _matches.CreateIfMutualRightAsync(fromUserId, toUser.Id, venue.Id, ct);
        return dto is null
            ? new SwipeResponse(false, null)
            : new SwipeResponse(true, dto.MatchGuid);
    }

    public async Task<FeedResponse> GetFeedAsync(
        long userId, Guid venueGuid, string? cursor, int limit = 20, CancellationToken ct = default)
    {
        if (limit < 1) limit = 1;
        if (limit > 50) limit = 50;

        var venue = await _db.Venues
            .Where(v => v.VenueGuid == venueGuid && v.Status == VenueStatus.Active)
            .Select(v => new { v.Id, v.Type })
            .FirstOrDefaultAsync(ct);
        if (venue is null) throw new InvalidOperationException("Venue not found or not active.");

        var hasMembership = await _db.VenueMemberships.AnyAsync(m =>
            m.VenueId == venue.Id && m.UserId == userId, ct);
        if (!hasMembership) throw new InvalidOperationException("Not checked in to this venue.");

        long cursorId = 0;
        if (!string.IsNullOrWhiteSpace(cursor) && !TryDecodeCursor(cursor, out cursorId))
            throw new InvalidOperationException("Invalid cursor.");

        var venueId = venue.Id;

        var (realItems, lastId) = venue.Type == VenueType.Global
            ? await GetGlobalCandidatesAsync(userId, venueId, cursorId, limit, ct)
            : await GetEventCandidatesAsync(userId, venueId, cursorId, limit, ct);

        string? nextCursor = lastId.HasValue ? EncodeCursor(lastId.Value) : null;
        return new FeedResponse(realItems, nextCursor);
    }

    private async Task<(List<FeedItemDto> Items, long? LastId)> GetEventCandidatesAsync(
        long userId, long venueId, long cursorId, int limit, CancellationToken ct)
    {
        var me = await _db.Users
            .Where(u => u.Id == userId)
            .Select(u => new { u.Gender, u.PreferGender })
            .FirstOrDefaultAsync(ct);
        var myGender = me?.Gender;
        var myPrefer = me?.PreferGender ?? GenderPreference.Everyone;

        // Load swiped and matched IDs upfront (faster than NOT EXISTS subqueries)
        var (swipedIds, matchedIds) = await LoadExcludedIdsAsync(userId, venueId, ct);

        // Simple query without correlated subqueries
        var query =
            from u in _db.Users
            join m in _db.VenueMemberships on u.Id equals m.UserId
            where !u.IsDeleted
                  && u.Id != userId
                  && u.Id > cursorId
                  && m.VenueId == venueId
                  && (myPrefer == GenderPreference.Everyone
                      || (myPrefer == GenderPreference.OnlyMale && u.Gender == Gender.Male)
                      || (myPrefer == GenderPreference.OnlyFemale && u.Gender == Gender.Female))
                  && (u.PreferGender == GenderPreference.Everyone
                      || (u.PreferGender == GenderPreference.OnlyMale && myGender == Gender.Male)
                      || (u.PreferGender == GenderPreference.OnlyFemale && myGender == Gender.Female))
            orderby u.Id ascending
            select new
            {
                u.Id,
                u.UserGuid,
                u.DisplayName,
                u.Bio,
                u.HasPhoto,
                u.BirthYear,
                u.Gender,
            };

        // Filter in memory using HashSets (O(1) lookups)
        var rows = await query
            .Where(u => !swipedIds.Contains(u.Id) && !matchedIds.Contains(u.Id))
            .Take(limit)
            .ToListAsync(ct);

        var items = rows
            .Select(u => new FeedItemDto(
                u.UserGuid,
                u.DisplayName,
                u.Bio,
                u.HasPhoto ? $"/api/v1/photos/{u.UserGuid}" : null,
                u.BirthYear,
                u.Gender?.ToString(),
                Kind: "user",
                Blur: null,
                StyleTags: null))
            .ToList();

        long? lastId = rows.Count == limit ? rows[^1].Id : null;
        return (items, lastId);
    }

    /// <summary>
    /// Load all user IDs that should be excluded from the feed (already swiped or matched).
    /// Using HashSets for O(1) lookup instead of NOT EXISTS subqueries.
    /// </summary>
    private async Task<(HashSet<long> SwipedIds, HashSet<long> MatchedIds)> LoadExcludedIdsAsync(
        long userId, long venueId, CancellationToken ct)
    {
        // Load swiped user IDs - uses index (FromUserId, VenueId)
        var swipedIds = await _db.Swipes
            .Where(s => s.FromUserId == userId && s.VenueId == venueId)
            .Select(s => s.ToUserId)
            .ToListAsync(ct);

        // Load matched user IDs - active matches only
        var matchedIds = await _db.Matches
            .Where(m => m.VenueId == venueId && m.EndedAt == null &&
                        (m.UserAId == userId || m.UserBId == userId))
            .Select(m => m.UserAId == userId ? m.UserBId : m.UserAId)
            .ToListAsync(ct);

        return (swipedIds.ToHashSet(), matchedIds.ToHashSet());
    }

    private async Task<(List<FeedItemDto> Items, long? LastId)> GetGlobalCandidatesAsync(
        long userId, long venueId, long cursorId, int limit, CancellationToken ct)
    {
        var me = await _db.VenueMemberships
            .Where(m => m.VenueId == venueId && m.UserId == userId)
            .Select(m => new { m.LastLat, m.LastLng, m.LastLocationAt })
            .FirstOrDefaultAsync(ct);

        // Degraded mode: no snapshot location yet — fall back to unfiltered feed
        // so the user isn't trapped with an empty deck on first load.
        if (me is null || me.LastLocationAt == default)
        {
            return await GetEventCandidatesAsync(userId, venueId, cursorId, limit, ct);
        }

        var myPrefs = await _db.Users
            .Where(u => u.Id == userId)
            .Select(u => new { u.Gender, u.PreferGender })
            .FirstOrDefaultAsync(ct);
        var myGender = myPrefs?.Gender;
        var myPrefer = myPrefs?.PreferGender ?? GenderPreference.Everyone;

        var radiusM = _geo.MeetupRadiusM;
        var dLat = radiusM / 111_320.0;
        var cos = Math.Cos(me.LastLat * Math.PI / 180.0);
        var dLng = cos == 0 ? 180.0 : radiusM / (111_320.0 * cos);
        var minLat = me.LastLat - dLat;
        var maxLat = me.LastLat + dLat;
        var minLng = me.LastLng - dLng;
        var maxLng = me.LastLng + dLng;

        // Load swiped and matched IDs upfront (faster than NOT EXISTS subqueries)
        var (swipedIds, matchedIds) = await LoadExcludedIdsAsync(userId, venueId, ct);

        var query =
            from u in _db.Users
            join m in _db.VenueMemberships on u.Id equals m.UserId
            where !u.IsDeleted
                  && u.Id != userId
                  && u.Id > cursorId
                  && m.VenueId == venueId
                  && m.LastLocationAt != default
                  && m.LastLat >= minLat && m.LastLat <= maxLat
                  && m.LastLng >= minLng && m.LastLng <= maxLng
                  && (myPrefer == GenderPreference.Everyone
                      || (myPrefer == GenderPreference.OnlyMale && u.Gender == Gender.Male)
                      || (myPrefer == GenderPreference.OnlyFemale && u.Gender == Gender.Female))
                  && (u.PreferGender == GenderPreference.Everyone
                      || (u.PreferGender == GenderPreference.OnlyMale && myGender == Gender.Male)
                      || (u.PreferGender == GenderPreference.OnlyFemale && myGender == Gender.Female))
            orderby u.Id ascending
            select new
            {
                u.Id,
                u.UserGuid,
                u.DisplayName,
                u.Bio,
                u.HasPhoto,
                u.BirthYear,
                u.Gender,
                m.LastLat,
                m.LastLng,
            };

        // Filter in memory using HashSets (O(1) lookups)
        var rows = await query
            .Where(u => !swipedIds.Contains(u.Id) && !matchedIds.Contains(u.Id))
            .ToListAsync(ct);

        var filtered = rows
            .Where(r => GeoMath.DistanceMeters(me.LastLat, me.LastLng, r.LastLat, r.LastLng) <= radiusM)
            .Take(limit)
            .ToList();

        var items = filtered
            .Select(u => new FeedItemDto(
                u.UserGuid,
                u.DisplayName,
                u.Bio,
                u.HasPhoto ? $"/api/v1/photos/{u.UserGuid}" : null,
                u.BirthYear,
                u.Gender?.ToString(),
                Kind: "user",
                Blur: null,
                StyleTags: null))
            .ToList();

        long? lastId = filtered.Count == limit ? filtered[^1].Id : null;
        return (items, lastId);
    }

    private static string EncodeCursor(long id)
    {
        var bytes = Encoding.UTF8.GetBytes(id.ToString(System.Globalization.CultureInfo.InvariantCulture));
        return Base64UrlEncode(bytes);
    }

    private static bool TryDecodeCursor(string cursor, out long id)
    {
        id = 0;
        try
        {
            var bytes = Base64UrlDecode(cursor);
            var s = Encoding.UTF8.GetString(bytes);
            return long.TryParse(s, System.Globalization.NumberStyles.Integer,
                System.Globalization.CultureInfo.InvariantCulture, out id);
        }
        catch
        {
            return false;
        }
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static byte[] Base64UrlDecode(string s)
    {
        var t = s.Replace('-', '+').Replace('_', '/');
        switch (t.Length % 4)
        {
            case 2: t += "=="; break;
            case 3: t += "="; break;
        }
        return Convert.FromBase64String(t);
    }
}
