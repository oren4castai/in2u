using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Matches;
using In2U.Api.Entities;
using In2U.Api.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Services;

public sealed class MatchService : IMatchService
{
    private readonly AppDbContext _db;
    private readonly IHubContext<VenueHub> _hub;
    private readonly IPushService _push;
    private readonly IGeoMembershipTracker _tracker;
    private readonly ILogger<MatchService> _log;

    public MatchService(
        AppDbContext db,
        IHubContext<VenueHub> hub,
        IPushService push,
        IGeoMembershipTracker tracker,
        ILogger<MatchService> log)
    {
        _db = db;
        _hub = hub;
        _push = push;
        _tracker = tracker;
        _log = log;
    }

    public async Task<MatchDto?> CreateIfMutualRightAsync(
        long fromUserId, long toUserId, long venueId, CancellationToken ct = default)
    {
        if (fromUserId == toUserId) return null;

        var reciprocalRight = await _db.Swipes.AnyAsync(s =>
            s.FromUserId == toUserId &&
            s.ToUserId == fromUserId &&
            s.VenueId == venueId &&
            s.Direction == SwipeDirection.Right, ct);
        if (!reciprocalRight) return null;

        var a = Math.Min(fromUserId, toUserId);
        var b = Math.Max(fromUserId, toUserId);
        var now = DateTime.UtcNow;

        var existingActive = await _db.Matches.FirstOrDefaultAsync(m =>
            m.VenueId == venueId && m.UserAId == a && m.UserBId == b && m.EndedAt == null, ct);

        Match match;
        if (existingActive is not null)
        {
            match = existingActive;
        }
        else
        {
            match = new Match
            {
                VenueId = venueId,
                UserAId = a,
                UserBId = b,
                CreatedAt = now,
                EndedAt = null,
            };
            _db.Matches.Add(match);
            try
            {
                await _db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                _db.Entry(match).State = EntityState.Detached;
                var reload = await _db.Matches.FirstOrDefaultAsync(m =>
                    m.VenueId == venueId && m.UserAId == a && m.UserBId == b && m.EndedAt == null, ct);
                if (reload is null) return null;
                match = reload;
            }

            await _db.VenueStats
                .Where(s => s.VenueId == venueId)
                .ExecuteUpdateAsync(s => s
                    .SetProperty(x => x.MatchesCount, x => x.MatchesCount + 1)
                    .SetProperty(x => x.UpdatedAt, DateTime.UtcNow), ct);
        }

        var venue = await _db.Venues
            .Where(v => v.Id == venueId)
            .Select(v => new { v.VenueGuid, v.Name })
            .FirstOrDefaultAsync(ct);
        if (venue is null) return null;

        var users = await _db.Users
            .Where(u => u.Id == a || u.Id == b)
            .Select(u => new
            {
                u.Id,
                u.UserGuid,
                u.DisplayName,
                u.Bio,
                u.HasPhoto,
                u.BirthYear,
                u.Gender,
            })
            .ToListAsync(ct);

        var userA = users.FirstOrDefault(u => u.Id == a);
        var userB = users.FirstOrDefault(u => u.Id == b);
        if (userA is null || userB is null) return null;

        MatchPeerDto PeerFor(long viewerId)
        {
            var peer = viewerId == a ? userB : userA;
            return new MatchPeerDto(
                peer.UserGuid,
                peer.DisplayName,
                peer.Bio,
                peer.HasPhoto ? $"/api/v1/photos/{peer.UserGuid}" : null,
                peer.BirthYear,
                peer.Gender?.ToString());
        }

        var dtoForA = new MatchDto(match.MatchGuid, venue.VenueGuid, venue.Name, match.CreatedAt, PeerFor(a));
        var dtoForB = new MatchDto(match.MatchGuid, venue.VenueGuid, venue.Name, match.CreatedAt, PeerFor(b));

        await _hub.Clients.User(userA.UserGuid.ToString()).SendAsync("MatchCreated", dtoForA, ct);
        await _hub.Clients.User(userB.UserGuid.ToString()).SendAsync("MatchCreated", dtoForB, ct);

        TryPushMatch(userA.UserGuid, userB.DisplayName, match.MatchGuid, venue.VenueGuid, userB.UserGuid);
        TryPushMatch(userB.UserGuid, userA.DisplayName, match.MatchGuid, venue.VenueGuid, userA.UserGuid);

        return fromUserId == a ? dtoForA : dtoForB;
    }

    private void TryPushMatch(Guid recipientGuid, string peerDisplayName, Guid matchGuid, Guid venueGuid, Guid peerUserGuid)
    {
        if (!_tracker.ShouldPush(recipientGuid)) return;
        var data = new Dictionary<string, string>
        {
            ["type"] = "match",
            ["matchGuid"] = matchGuid.ToString(),
            ["venueGuid"] = venueGuid.ToString(),
            ["peerUserGuid"] = peerUserGuid.ToString(),
        };
        var notification = new PushNotification(
            "New match!",
            $"You matched with {peerDisplayName}",
            data);
        _ = Task.Run(async () =>
        {
            try
            {
                await _push.SendToUserGuidAsync(recipientGuid, notification, CancellationToken.None);
            }
            catch (Exception ex)
            {
                _log.LogWarning(ex, "Push for match failed.");
            }
        });
    }

    public async Task<IReadOnlyList<MatchDto>> ListActiveForUserAsync(long userId, CancellationToken ct = default)
    {
        var rows = await _db.Matches
            .Where(m => m.EndedAt == null && (m.UserAId == userId || m.UserBId == userId))
            .Join(_db.Venues, m => m.VenueId, v => v.Id, (m, v) => new { m, v })
            .Select(x => new
            {
                x.m.MatchGuid,
                x.m.CreatedAt,
                x.m.UserAId,
                x.m.UserBId,
                VenueGuid = x.v.VenueGuid,
                VenueName = x.v.Name,
            })
            .ToListAsync(ct);

        if (rows.Count == 0) return Array.Empty<MatchDto>();

        var peerIds = rows.Select(r => r.UserAId == userId ? r.UserBId : r.UserAId).Distinct().ToList();
        var peers = await _db.Users
            .Where(u => peerIds.Contains(u.Id))
            .Select(u => new
            {
                u.Id,
                u.UserGuid,
                u.DisplayName,
                u.Bio,
                u.HasPhoto,
                u.BirthYear,
                u.Gender,
            })
            .ToDictionaryAsync(u => u.Id, ct);

        var result = new List<MatchDto>(rows.Count);
        foreach (var r in rows)
        {
            var peerId = r.UserAId == userId ? r.UserBId : r.UserAId;
            if (!peers.TryGetValue(peerId, out var p)) continue;
            result.Add(new MatchDto(
                r.MatchGuid,
                r.VenueGuid,
                r.VenueName,
                r.CreatedAt,
                new MatchPeerDto(p.UserGuid, p.DisplayName, p.Bio, p.HasPhoto ? $"/api/v1/photos/{p.UserGuid}" : null, p.BirthYear, p.Gender?.ToString())));
        }
        return result;
    }

    public async Task<bool> EndMatchAsync(
        Guid matchGuid, long requesterUserId, MatchEndReason reason, CancellationToken ct = default)
    {
        var match = await _db.Matches.FirstOrDefaultAsync(m => m.MatchGuid == matchGuid, ct);
        if (match is null) return false;
        if (match.UserAId != requesterUserId && match.UserBId != requesterUserId) return false;

        await HardDeleteAsync(new[] { match }, reason, ct);
        return true;
    }

    public async Task EndMembershipMatchesAsync(
        long userId, long venueId, MatchEndReason reason, CancellationToken ct = default)
    {
        var active = await _db.Matches
            .Where(m => m.VenueId == venueId
                        && m.EndedAt == null
                        && (m.UserAId == userId || m.UserBId == userId))
            .ToListAsync(ct);
        if (active.Count == 0) return;

        await HardDeleteAsync(active, reason, ct);
    }

    public async Task EndVenueMatchesAsync(long venueId, MatchEndReason reason, CancellationToken ct = default)
    {
        var active = await _db.Matches
            .Where(m => m.VenueId == venueId && m.EndedAt == null)
            .ToListAsync(ct);
        if (active.Count == 0) return;

        await HardDeleteAsync(active, reason, ct);
    }

    public async Task EndMatchesBetweenAsync(
        long userAId, long userBId, MatchEndReason reason, CancellationToken ct = default)
    {
        var a = Math.Min(userAId, userBId);
        var b = Math.Max(userAId, userBId);

        var active = await _db.Matches
            .Where(m => m.UserAId == a && m.UserBId == b && m.EndedAt == null)
            .ToListAsync(ct);
        if (active.Count == 0) return;

        await HardDeleteAsync(active, reason, ct);
    }

    public async Task EndAllUserMatchesAsync(long userId, MatchEndReason reason, CancellationToken ct = default)
    {
        var all = await _db.Matches
            .Where(m => m.UserAId == userId || m.UserBId == userId)
            .ToListAsync(ct);
        if (all.Count == 0) return;

        await HardDeleteAsync(all, reason, ct);
    }

    private async Task HardDeleteAsync(
        IReadOnlyList<Match> matches, MatchEndReason reason, CancellationToken ct)
    {
        if (matches.Count == 0) return;

        var matchIds = matches.Select(m => m.Id).ToList();
        var userIds = matches.SelectMany(m => new[] { m.UserAId, m.UserBId }).Distinct().ToList();

        var userGuidLookup = await _db.Users
            .Where(u => userIds.Contains(u.Id))
            .Select(u => new { u.Id, u.UserGuid })
            .ToDictionaryAsync(u => u.Id, u => u.UserGuid, ct);

        // 1) Broadcast MatchEnded FIRST so clients are notified before the data disappears.
        foreach (var m in matches)
        {
            var payload = new MatchEndedDto(m.MatchGuid, reason.ToString());
            if (userGuidLookup.TryGetValue(m.UserAId, out var ga))
                await _hub.Clients.User(ga.ToString()).SendAsync("MatchEnded", payload, ct);
            if (userGuidLookup.TryGetValue(m.UserBId, out var gb))
                await _hub.Clients.User(gb.ToString()).SendAsync("MatchEnded", payload, ct);
        }

        // 2) Hard-delete chat messages + matches in a single transaction.
        await using var tx = await _db.Database.BeginTransactionAsync(ct);
        await _db.ChatMessages.Where(c => matchIds.Contains(c.MatchId)).ExecuteDeleteAsync(ct);
        await _db.Matches.Where(m => matchIds.Contains(m.Id)).ExecuteDeleteAsync(ct);
        foreach (var m in matches)
        {
            var entry = _db.Entry(m);
            if (entry.State != EntityState.Detached) entry.State = EntityState.Detached;
        }
        await tx.CommitAsync(ct);
    }
}
