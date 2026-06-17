using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Ambient;
using In2U.Api.Dtos.Venues;
using In2U.Api.Entities;
using In2U.Api.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Services;

public sealed class VenueService : IVenueService
{
    private readonly AppDbContext _db;
    private readonly IPresenceService _presence;
    private readonly IGeoMembershipTracker _tracker;
    private readonly IHubContext<VenueHub> _hub;
    private readonly IMatchService _matches;
    private readonly IPushService _push;
    private readonly IAmbientProfileService _ambient;
    private readonly ILogger<VenueService> _log;
    private readonly ILocationValidationService _locationValidation;
    private static readonly IReadOnlyList<string> EmptyAvatars = Array.Empty<string>();
    private static readonly IReadOnlyList<AmbientPreviewDto> EmptyAmbient = Array.Empty<AmbientPreviewDto>();

    public VenueService(
        AppDbContext db,
        IPresenceService presence,
        IGeoMembershipTracker tracker,
        IHubContext<VenueHub> hub,
        IMatchService matches,
        IPushService push,
        IAmbientProfileService ambient,
        ILogger<VenueService> log,
        ILocationValidationService locationValidation)
    {
        _db = db;
        _presence = presence;
        _tracker = tracker;
        _hub = hub;
        _matches = matches;
        _push = push;
        _ambient = ambient;
        _log = log;
        _locationValidation = locationValidation;
    }

    private async Task BroadcastEventListChangedAsync(Guid venueGuid, string kind, CancellationToken ct)
    {
        try
        {
            await _hub.Clients.All.SendAsync(
                "EventListChanged",
                new { venueGuid, kind },
                ct);
        }
        catch
        {
            // Best-effort broadcast; never fail the caller.
        }
    }

    public async Task<IReadOnlyList<DiscoverVenueDto>> DiscoverAsync(
        double lat, double lng, int radiusM, int limit = 50, EventCategory? category = null, CancellationToken ct = default)
    {
        if (radiusM <= 0) radiusM = 2000;
        if (limit <= 0 || limit > 200) limit = 50;

        var dLat = radiusM / 111_320.0;
        var cos = Math.Cos(lat * Math.PI / 180.0);
        var dLng = cos == 0 ? 180.0 : radiusM / (111_320.0 * cos);

        var minLat = lat - dLat;
        var maxLat = lat + dLat;
        var minLng = lng - dLng;
        var maxLng = lng + dLng;

        var now = DateTime.UtcNow;

        var candidatesQuery = _db.Venues
            .Where(v => v.Status == VenueStatus.Active
                        && !v.IsPaused
                        && (v.Type == VenueType.Global  // Global venues always visible
                            || (v.Lat >= minLat && v.Lat <= maxLat && v.Lng >= minLng && v.Lng <= maxLng))
                        && (v.Type == VenueType.Global
                            || (v.DurationHours == null || v.StartsAt == null || v.StartsAt.Value.AddHours((double)v.DurationHours.Value) >= now)));

        if (category.HasValue)
            candidatesQuery = candidatesQuery.Where(v => v.Category == category.Value);

        var candidates = await candidatesQuery.ToListAsync(ct);

        var filtered = candidates
            .Select(v => new
            {
                Venue = v,
                Distance = GeoMath.DistanceMeters(lat, lng, v.Lat, v.Lng),
            })
            .Where(x => x.Venue.Type == VenueType.Global || x.Distance <= radiusM)
            .OrderByDescending(x => x.Venue.Type == VenueType.Global)
            .ThenBy(x => x.Distance)
            .Take(limit)
            .ToList();

        // Batch-fetch owner names for governed events
        var ownerIds = filtered
            .Where(x => x.Venue.OwnerId.HasValue)
            .Select(x => x.Venue.OwnerId!.Value)
            .Distinct()
            .ToList();
        var ownerNames = ownerIds.Count > 0
            ? await _db.VenueOwners
                .Where(o => ownerIds.Contains(o.Id))
                .ToDictionaryAsync(o => o.Id, o => o.Name, ct)
            : new Dictionary<long, string>();

        var result = new List<DiscoverVenueDto>(filtered.Count);
        foreach (var x in filtered)
        {
            var bucket = await _presence.DensityBucketAsync(x.Venue.Id, ct);
            var ambient = await _ambient.GetVenuePreviewAsync(x.Venue.Id, max: null, ct);
            var ownerName = x.Venue.OwnerId.HasValue && ownerNames.TryGetValue(x.Venue.OwnerId.Value, out var n) ? n : null;
            result.Add(new DiscoverVenueDto(
                x.Venue.VenueGuid,
                x.Venue.Name,
                x.Venue.Type.ToString(),
                x.Venue.EventType.ToString(),
                x.Venue.Lat,
                x.Venue.Lng,
                x.Venue.RadiusM,
                x.Venue.Type == VenueType.Global ? 0 : x.Distance, // Global has no meaningful distance
                bucket,
                x.Venue.StartsAt,
                x.Venue.DurationHours,
                x.Venue.Status.ToString(),
                x.Venue.HasPhoto,
                EmptyAvatars,
                ambient,
                x.Venue.Category?.ToString(),
                ownerName));
        }
        return result;
    }

    public async Task<VenueDetailsDto?> GetByGuidAsync(
        Guid venueGuid, double? originLat = null, double? originLng = null, CancellationToken ct = default)
    {
        var v = await _db.Venues.FirstOrDefaultAsync(x => x.VenueGuid == venueGuid, ct);
        if (v is null) return null;
        // Allow closed venues — client shows a "Closed" status banner
        // Only increment view stats for active venues
        if (v.Status != VenueStatus.Active)
        {
            var distance2 = (originLat.HasValue && originLng.HasValue)
                ? GeoMath.DistanceMeters(originLat.Value, originLng.Value, v.Lat, v.Lng)
                : 0.0;
            var bucket2 = await _presence.DensityBucketAsync(v.Id, ct);
            var ambient2 = await _ambient.GetVenuePreviewAsync(v.Id, max: null, ct);
            return new VenueDetailsDto(
                v.VenueGuid,
                v.Name,
                v.Description,
                v.Type.ToString(),
                v.EventType.ToString(),
                v.Lat,
                v.Lng,
                v.RadiusM,
                distance2,
                bucket2,
                v.StartsAt,
                v.DurationHours,
                v.Status.ToString(),
                v.HasPhoto,
                EmptyAvatars,
                ambient2,
                v.Category?.ToString());
        }

        var updated = await _db.VenueStats
            .Where(s => s.VenueId == v.Id)
            .ExecuteUpdateAsync(s => s
                .SetProperty(x => x.ViewsCount, x => x.ViewsCount + 1)
                .SetProperty(x => x.UpdatedAt, DateTime.UtcNow), ct);
        if (updated == 0)
        {
            try
            {
                _db.VenueStats.Add(new VenueStats { VenueId = v.Id, ViewsCount = 1 });
                await _db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException ex)
            {
                _log.LogWarning(ex, "Failed to create venue stats for venue {VenueId}", v.Id);
                var stats = _db.VenueStats.Local.LastOrDefault();
                if (stats is not null)
                    _db.Entry(stats).State = EntityState.Detached;
            }
        }

        var bucket = await _presence.DensityBucketAsync(v.Id, ct);
        var distance = (originLat.HasValue && originLng.HasValue)
            ? GeoMath.DistanceMeters(originLat.Value, originLng.Value, v.Lat, v.Lng)
            : 0.0;

        var ambient = await _ambient.GetVenuePreviewAsync(v.Id, max: null, ct);
        return new VenueDetailsDto(
            v.VenueGuid,
            v.Name,
            v.Description,
            v.Type.ToString(),
            v.EventType.ToString(),
            v.Lat,
            v.Lng,
            v.RadiusM,
            distance,
            bucket,
            v.StartsAt,
            v.DurationHours,
            v.Status.ToString(),
            v.HasPhoto,
            EmptyAvatars,
            ambient,
            v.Category?.ToString());
    }

    public async Task<CheckInResponse> CheckInAsync(
        long userId, Guid userGuid, Guid venueGuid, double lat, double lng, CancellationToken ct = default)
    {
        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct)
                    ?? throw new InvalidOperationException("Venue not found.");

        var checkUser = await _db.Users
            .Where(u => u.Id == userId)
            .Select(u => new { u.HasPhoto })
            .FirstOrDefaultAsync(ct);
        if (checkUser?.HasPhoto != true)
            throw new InvalidOperationException("Add a photo to your profile before checking in.");

        if (venue.Status != VenueStatus.Active)
            throw new InvalidOperationException("Venue is not active.");



 

        var now = DateTime.UtcNow;
        if (venue.Type == VenueType.Event)
        {
            if (venue.StartsAt is not null && now < venue.StartsAt.Value)
                throw new InvalidOperationException("Event has not started.");
            if (venue.StartsAt is not null && venue.DurationHours is not null && now > venue.StartsAt.Value.AddHours(venue.DurationHours.Value))
                throw new InvalidOperationException("Event has ended.");
        }

        // TESTING ONLY — distance check disabled, restore before production
        // if (venue.Type != VenueType.Global)
        // {
        //     var distance = GeoMath.DistanceMeters(venue.Lat, venue.Lng, lat, lng);
        //     if (distance > venue.RadiusM)
        //         throw new InvalidOperationException("You are outside the venue radius.");
        // }

        // Existing membership for this user (any venue).
        var existing = await _db.VenueMemberships
            .FirstOrDefaultAsync(m => m.UserId == userId, ct);

        if (existing is not null)
        {
            if (existing.VenueId == venue.Id)
            {
                return new CheckInResponse(existing.MembershipGuid, venue.VenueGuid, existing.CheckedInAt);
            }

            // Auto-leave prior venue — hard-delete the old membership and its data.
            var priorVenueId = existing.VenueId;
            await _db.VenueMemberships.Where(x => x.Id == existing.Id).ExecuteDeleteAsync(ct);
            await _db.Swipes
                .Where(s => (s.FromUserId == userId || s.ToUserId == userId) && s.VenueId == priorVenueId)
                .ExecuteDeleteAsync(ct);
            await _db.AmbientSwipes
                .Where(s => s.FromUserId == userId && s.VenueId == priorVenueId)
                .ExecuteDeleteAsync(ct);

            await _matches.EndMembershipMatchesAsync(userId, priorVenueId, MatchEndReason.UserLeft, ct);

            var priorVenueGuid = await _db.Venues
                .Where(v => v.Id == priorVenueId)
                .Select(v => v.VenueGuid)
                .FirstOrDefaultAsync(ct);

            if (priorVenueGuid != Guid.Empty)
            {
                await _hub.Clients.User(userGuid.ToString()).SendAsync(
                    "VenueLeft", new { venueGuid = priorVenueGuid, reason = "switched" }, ct);
                await _presence.BroadcastPresenceUpdatedAsync(priorVenueId, priorVenueGuid, ct);
            }
        }

        var membership = new VenueMembership
        {
            UserId = userId,
            VenueId = venue.Id,
            CheckedInAt = now,
            LastActiveAtUtc = now,
            LastLocationAt = now,
            LastLat = lat,
            LastLng = lng,
        };
        _db.VenueMemberships.Add(membership);

        try
        {
            await _db.SaveChangesAsync(ct);

             // ADD THIS:
         await _db.VenueStats
            .Where(s => s.VenueId == venue.Id)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.JoinedCount, x => x.JoinedCount + 1), ct);
            
        }
        catch (DbUpdateException ex)
        {
            _log.LogWarning(ex, "Check-in conflict for user {UserId} venue {VenueId}", userId, venue.Id);
            _db.Entry(membership).State = EntityState.Detached;
            var current = await _db.VenueMemberships
                .FirstOrDefaultAsync(m => m.UserId == userId, ct);
            if (current is not null && current.VenueId == venue.Id)
                return new CheckInResponse(current.MembershipGuid, venue.VenueGuid, current.CheckedInAt);
            throw new InvalidOperationException("Check-in conflict; please retry.");
        }

        await _presence.BroadcastPresenceUpdatedAsync(venue.Id, venue.VenueGuid, ct);
        return new CheckInResponse(membership.MembershipGuid, venue.VenueGuid, membership.CheckedInAt);
    }

    public async Task LeaveAsync(long userId, Guid userGuid, Guid venueGuid, CancellationToken ct = default)
    {
        // Verify the user is actually checked in to this specific venue
        var venueId = await _db.VenueMemberships
            .Where(m => m.UserId == userId)
            .Join(_db.Venues, m => m.VenueId, v => v.Id, (m, v) => new { m, v })
            .Where(x => x.v.VenueGuid == venueGuid)
            .Select(x => (long?)x.v.Id)
            .FirstOrDefaultAsync(ct);

        if (venueId is null) return;

        // Reuse the full cleanup path: deletes swipes, ambient swipes, ends matches,
        // broadcasts ForceCheckout + PresenceUpdated, and push fallback.
        await _locationValidation.ForceCheckoutActiveAsync(userId, "user", ct);
    }

    public async Task<CreatedVenueDto> CreateAsync(CreateVenueRequest req, long createUserId, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(req.Name))
            throw new ArgumentException("Name is required.");
        if (req.RadiusM < 10 || req.RadiusM > 5000)
            throw new ArgumentException("RadiusM must be between 10 and 5000.");
        if (!Enum.TryParse<VenueType>(req.Type, ignoreCase: true, out var type))
            throw new ArgumentException("Invalid venue type.");
        if (type == VenueType.Event)
        {
            if (req.StartsAt is null || req.DurationHours is null)
                throw new ArgumentException("Event venues require StartsAt and DurationHours.");
            if (req.DurationHours <= 0)
                throw new ArgumentException("DurationHours must be greater than 0.");
        }

        var venue = new Venue
        {
            Name = req.Name.Trim(),
            Description = req.Description,
            Type = type,
            Lat = req.Lat,
            Lng = req.Lng,
            RadiusM = req.RadiusM,
            StartsAt = req.StartsAt,
            DurationHours = req.DurationHours,
            OwnerId = req.OwnerId,
            EventType = Enum.TryParse<VenueEventType>(req.EventType, ignoreCase: true, out var eventType) ? eventType : VenueEventType.Public,
            Category = Enum.TryParse<EventCategory>(req.Category, ignoreCase: true, out var category) ? category : null,
            Status = VenueStatus.Active,
            CreateUserId = createUserId,
            CreatedAt = DateTime.UtcNow,
            ShareCode = GenerateShareCode(),
        };
        _db.Venues.Add(venue);
        await _db.SaveChangesAsync(ct);
        _db.VenueStats.Add(new VenueStats { VenueId = venue.Id });
        await _db.SaveChangesAsync(ct);
        if (venue.Type == VenueType.Event)
            await BroadcastEventListChangedAsync(venue.VenueGuid, "created", ct);
        return new CreatedVenueDto(venue.VenueGuid, venue.Status.ToString());
    }

    public async Task<CloseVenueResponse> CloseAsync(Guid venueGuid, bool hardDelete = false, CancellationToken ct = default)
    {
        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct)
                    ?? throw new InvalidOperationException("Venue not found.");

        // NOTE: venue.Status = Closed is NOT mutated/saved here. It is only persisted
        // inside the soft-close branch below (the path where the row survives). For
        // hard-delete branches, mutating Status on the tracked entity would cause an
        // UPDATE against a row that ExecuteDeleteAsync removes — and leaking the
        // pre-save (the historical bug) left Closed/OwnerId=null orphans behind.

        // Load members before deleting to get user IDs for SignalR/push.
        var members = await _db.VenueMemberships
            .Where(m => m.VenueId == venue.Id)
            .Select(m => new { m.Id, m.UserId })
            .ToListAsync(ct);

        await _db.VenueMemberships.Where(m => m.VenueId == venue.Id).ExecuteDeleteAsync(ct);
        await _db.Swipes.Where(s => s.VenueId == venue.Id).ExecuteDeleteAsync(ct);
        await _db.AmbientSwipes.Where(s => s.VenueId == venue.Id).ExecuteDeleteAsync(ct);

        await _matches.EndVenueMatchesAsync(venue.Id, MatchEndReason.VenueClosed, ct);

        if (members.Count > 0)
        {
            var affectedUserIds = members.Select(m => m.UserId).Distinct().ToList();
            var userGuids = await _db.Users
                .Where(u => affectedUserIds.Contains(u.Id))
                .Select(u => u.UserGuid)
                .ToListAsync(ct);

            foreach (var ug in userGuids)
            {
                await _hub.Clients.User(ug.ToString()).SendAsync(
                    "ForceCheckout",
                    new { venueGuid = venue.VenueGuid, reason = "venueClosed" },
                    ct);

                if (!_tracker.IsConnected(ug))
                {
                    PushHelpers.TryPushCheckout(_push, _log, ug, venue.VenueGuid, "venueClosed");
                }
            }
        }

        await _presence.BroadcastPresenceUpdatedAsync(venue.Id, venue.VenueGuid, ct);

        // ── Post-close: log and hard/soft delete ──────────────────────────
        if (venue.OwnerId.HasValue)
        {
            // Always delete VenueStats and ambient assignments
            await _db.VenueStats.Where(s => s.VenueId == venue.Id).ExecuteDeleteAsync(ct);
            await _db.VenueAmbientAssignments.Where(a => a.VenueId == venue.Id).ExecuteDeleteAsync(ct);

            // Determine soft vs hard close:
            // Soft = owner's own event (VenueOwner.CreateUserId == venue.CreateUserId) → keep Venue + VenuePhoto
            // Hard = event created by someone else → delete Venue + VenuePhoto
            var owner = await _db.VenueOwners.FirstOrDefaultAsync(o => o.Id == venue.OwnerId.Value, ct);
            bool isSoftClose = !hardDelete && owner is not null && owner.CreateUserId == venue.CreateUserId;

            if (!isSoftClose)
            {
                // Hard close: log stats, then delete everything including venue and photos.
                var stats = await _db.VenueStats.FirstOrDefaultAsync(s => s.VenueId == venue.Id, ct);
                var creatorName = await _db.Users
                    .Where(u => u.Id == venue.CreateUserId)
                    .Select(u => u.DisplayName)
                    .FirstOrDefaultAsync(ct) ?? string.Empty;

                _db.VenueOwnerEventLogs.Add(new VenueOwnerEventLog
                {
                    VenueOwnerId = venue.OwnerId.Value,
                    VenueId = venue.Id,
                    Name = venue.Name,
                    Description = venue.Description,
                    StartsAt = venue.StartsAt,
                    DurationHours = venue.DurationHours,
                    EventType = venue.EventType.ToString(),
                    JoinedCount = stats?.JoinedCount ?? 0,
                    MatchesCount = stats?.MatchesCount ?? 0,
                    ViewsCount = stats?.ViewsCount ?? 0,
                    CreateUserName = creatorName,
                    ClosedAt = DateTime.UtcNow,
                });

                // Do NOT mutate venue.Status — the row is about to be deleted.
                await _db.VenueAmbientAssignments.Where(a => a.VenueId == venue.Id).ExecuteDeleteAsync(ct);
                var matchIdsA = await _db.Matches
                    .Where(m => m.VenueId == venue.Id)
                    .Select(m => m.Id)
                    .ToListAsync(ct);
                if (matchIdsA.Count > 0)
                    await _db.ChatMessages.Where(c => matchIdsA.Contains(c.MatchId)).ExecuteDeleteAsync(ct);
                await _db.Matches.Where(m => m.VenueId == venue.Id).ExecuteDeleteAsync(ct);
                await _db.VenuePhotos.Where(p => p.VenueId == venue.Id).ExecuteDeleteAsync(ct);
                await _db.Venues.Where(v => v.Id == venue.Id).ExecuteDeleteAsync(ct);
            }
            else
            {
                // Soft close: venue + photo stay as template. Persist Status=Closed here.
                // No log entry — the event is still alive and can be rescheduled.
                venue.Status = VenueStatus.Closed;
                var matchIdsS = await _db.Matches
                    .Where(m => m.VenueId == venue.Id)
                    .Select(m => m.Id)
                    .ToListAsync(ct);
                if (matchIdsS.Count > 0)
                    await _db.ChatMessages.Where(c => matchIdsS.Contains(c.MatchId)).ExecuteDeleteAsync(ct);
                await _db.Matches.Where(m => m.VenueId == venue.Id).ExecuteDeleteAsync(ct);
            }

            if (isSoftClose)
                await BroadcastEventListChangedAsync(venue.VenueGuid, "closed", ct);
            else
                await BroadcastEventListChangedAsync(venueGuid, "deleted", ct);

            await _db.SaveChangesAsync(ct);
        }
        else
        {
            // No VenueOwner — hard delete everything
            await _db.VenueAmbientAssignments.Where(a => a.VenueId == venue.Id).ExecuteDeleteAsync(ct);
            var matchIds = await _db.Matches
                .Where(m => m.VenueId == venue.Id)
                .Select(m => m.Id)
                .ToListAsync(ct);
            if (matchIds.Count > 0)
                await _db.ChatMessages.Where(c => matchIds.Contains(c.MatchId)).ExecuteDeleteAsync(ct);

            await BroadcastEventListChangedAsync(venueGuid, "deleted", ct);
            await _db.Matches.Where(m => m.VenueId == venue.Id).ExecuteDeleteAsync(ct);
            await _db.VenueStats.Where(s => s.VenueId == venue.Id).ExecuteDeleteAsync(ct);
            await _db.VenuePhotos.Where(p => p.VenueId == venue.Id).ExecuteDeleteAsync(ct);
            await _db.Venues.Where(v => v.Id == venue.Id).ExecuteDeleteAsync(ct);
            await _db.SaveChangesAsync(ct);
        }

        return new CloseVenueResponse(venue.VenueGuid, VenueStatus.Closed.ToString());
    }

    public async Task<VenueStatsDto?> GetStatsAsync(Guid venueGuid, CancellationToken ct = default)
    {
        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct);
        if (venue is null) return null;

        var stats = await _db.VenueStats.FirstOrDefaultAsync(s => s.VenueId == venue.Id, ct);
        if (stats is null)
        {
            stats = new VenueStats { VenueId = venue.Id };
            _db.VenueStats.Add(stats);
            try { await _db.SaveChangesAsync(ct); }
            catch (DbUpdateException)
            {
                _db.Entry(stats).State = EntityState.Detached;
                stats = await _db.VenueStats.FirstOrDefaultAsync(s => s.VenueId == venue.Id, ct) ?? new VenueStats { VenueId = venue.Id };
            }
        }

        var joinedCount = await _db.VenueMemberships.CountAsync(m => m.VenueId == venue.Id, ct);

        return new VenueStatsDto(
            joinedCount,
            stats.MatchesCount,
            stats.ViewsCount,
            venue.ShareCode,
            GenerateIntSparkline(joinedCount),
            GenerateIntSparkline(stats.MatchesCount),
            GenerateLongSparkline(stats.ViewsCount));
    }

    public async Task<IReadOnlyList<VenueParticipantDto>> GetParticipantsAsync(Guid venueGuid, string? search, CancellationToken ct = default)
    {
        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct);
        if (venue is null) return Array.Empty<VenueParticipantDto>();

        var query = _db.VenueMemberships
            .Where(m => m.VenueId == venue.Id)
            .Join(_db.Users, m => m.UserId, u => u.Id, (m, u) => new { m, u });

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(x => x.u.DisplayName.ToLower().Contains(search.ToLower()));

        return await query
            .Select(x => new VenueParticipantDto(
                x.u.UserGuid,
                x.u.DisplayName,
                x.u.HasPhoto,
                x.u.BirthYear,
                x.m.CheckedInAt))
            .ToListAsync(ct);
    }

    public async Task ForceCheckoutParticipantAsync(Guid venueGuid, Guid targetUserGuid, CancellationToken ct = default)
    {
        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct);
        if (venue is null) return;

        var targetUserId = await _db.Users
            .Where(u => u.UserGuid == targetUserGuid && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (targetUserId is null) return;

        var inVenue = await _db.VenueMemberships.AnyAsync(m => m.UserId == targetUserId.Value && m.VenueId == venue.Id, ct);
        if (!inVenue) return;

        await _locationValidation.ForceCheckoutActiveAsync(targetUserId.Value, "admin", ct);
    }

    public async Task<IReadOnlyList<MyEventDto>> GetMyEventsAsync(long userId, CancellationToken ct = default)
    {
        var ownedOwnerIds = await _db.VenueOwners
            .Where(o => o.CreateUserId == userId)
            .Select(o => o.Id)
            .ToListAsync(ct);

        return await _db.Venues
            .Where(v => v.CreateUserId == userId
                        && v.Type == VenueType.Event
                        && v.Status == VenueStatus.Active
                        && (v.OwnerId == null || !ownedOwnerIds.Contains(v.OwnerId.Value)))
            .OrderByDescending(v => v.CreatedAt)
            .Select(v => new MyEventDto(
                v.VenueGuid,
                v.Name,
                v.Description,
                v.EventType.ToString(),
                v.Lat,
                v.Lng,
                v.RadiusM,
                v.StartsAt,
                v.DurationHours,
                v.Status.ToString(),
                v.HasPhoto,
                v.HasPhoto ? $"/api/v1/photos/venue/{v.VenueGuid}" : null,
                v.ShareCode))
            .ToListAsync(ct);
    }

    public async Task<MyEventDto?> PatchEventAsync(Guid venueGuid, PatchEventRequest req, CancellationToken ct = default)
    {
        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct);
        if (venue is null) return null;

        if (!string.IsNullOrWhiteSpace(req.Name))
            venue.Name = req.Name.Trim();
        if (req.Description is not null)
            venue.Description = req.Description;
        if (req.DurationHours.HasValue && req.DurationHours.Value > 0)
            venue.DurationHours = req.DurationHours.Value;

        await _db.SaveChangesAsync(ct);

        return new MyEventDto(
            venue.VenueGuid,
            venue.Name,
            venue.Description,
            venue.EventType.ToString(),
            venue.Lat,
            venue.Lng,
            venue.RadiusM,
            venue.StartsAt,
            venue.DurationHours,
            venue.Status.ToString(),
            venue.HasPhoto,
            venue.HasPhoto ? $"/api/v1/photos/venue/{venue.VenueGuid}" : null,
            venue.ShareCode);
    }

    private static readonly char[] ShareCodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".ToCharArray();

    private static string GenerateShareCode()
    {
        var bytes = new byte[8];
        System.Security.Cryptography.RandomNumberGenerator.Fill(bytes);
        return new string(bytes.Select(b => ShareCodeChars[b % ShareCodeChars.Length]).ToArray());
    }

    private static int[] GenerateIntSparkline(int current, int points = 8)
    {
        if (current == 0) return Array.Empty<int>();
        var rng = Random.Shared;
        var result = new int[points];
        for (int i = 0; i < points - 1; i++)
            result[i] = Math.Max(0, (int)(current * (0.2 + 0.8 * i / (points - 1)) + rng.Next(-(current / 10 + 1), current / 10 + 2)));
        result[points - 1] = current;
        return result;
    }

    private static long[] GenerateLongSparkline(long current, int points = 8)
    {
        if (current == 0) return Array.Empty<long>();
        var rng = Random.Shared;
        var result = new long[points];
        for (int i = 0; i < points - 1; i++)
            result[i] = Math.Max(0, (long)(current * (0.2 + 0.8 * i / (points - 1)) + rng.Next(-((int)(current / 10) + 1), (int)(current / 10) + 2)));
        result[points - 1] = current;
        return result;
    }
}
