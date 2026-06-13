using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Entities;
using In2U.Api.Hubs;
using In2U.Api.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace In2U.Api.BackgroundServices;

public sealed class CleanupHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IHubContext<VenueHub> _hub;
    private readonly ILogger<CleanupHostedService> _logger;
    private readonly CleanupOptions _cleanup;
    private readonly GeoOptions _geo;

    public CleanupHostedService(
        IServiceScopeFactory scopeFactory,
        IHubContext<VenueHub> hub,
        ILogger<CleanupHostedService> logger,
        IOptions<CleanupOptions> cleanupOpts,
        IOptions<GeoOptions> geoOpts)
    {
        _scopeFactory = scopeFactory;
        _hub = hub;
        _logger = logger;
        _cleanup = cleanupOpts.Value;
        _geo = geoOpts.Value;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var interval = TimeSpan.FromSeconds(Math.Max(5, _cleanup.SweepIntervalS));
        var timer = new PeriodicTimer(interval);
        try
        {
            try
            {
                await TickAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Cleanup startup tick failed.");
            }

            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                try
                {
                    await TickAsync(stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Cleanup tick failed.");
                }
            }
        }
        catch (OperationCanceledException) { }
    }

    private async Task TickAsync(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var tracker = scope.ServiceProvider.GetRequiredService<IGeoMembershipTracker>();
        var matches = scope.ServiceProvider.GetRequiredService<IMatchService>();
        var push = scope.ServiceProvider.GetRequiredService<IPushService>();

        var now = DateTime.UtcNow;

        var affectedVenueIds = new HashSet<long>();
        var forceCheckouts = new List<(Guid UserGuid, Guid VenueGuid, string Reason)>();
        var membershipMatchEnds = new List<(long UserId, long VenueId)>();
        var venueMatchEnds = new HashSet<long>();

        // 1b. Inactive sweep (global venues only).
        var inactiveThreshold = now.AddMinutes(-_geo.GlobalInactiveTimeoutMinutes);
        var inactiveGlobals = await db.VenueMemberships
            .Where(m => m.LastLocationAt != default && m.LastLocationAt < inactiveThreshold)
            .Join(db.Venues, m => m.VenueId, v => v.Id, (m, v) => new { m, v })
            .Where(x => x.v.Type == VenueType.Global)
            .ToListAsync(ct);

        var inactiveMembershipIds = new List<long>();
        if (inactiveGlobals.Count > 0)
        {
            var userIds = inactiveGlobals.Select(x => x.m.UserId).Distinct().ToList();
            var userLookup = await db.Users
                .Where(u => userIds.Contains(u.Id))
                .Select(u => new { u.Id, u.UserGuid })
                .ToDictionaryAsync(u => u.Id, u => u.UserGuid, ct);

            foreach (var x in inactiveGlobals)
            {
                inactiveMembershipIds.Add(x.m.Id);
                affectedVenueIds.Add(x.m.VenueId);
                membershipMatchEnds.Add((x.m.UserId, x.m.VenueId));
                if (userLookup.TryGetValue(x.m.UserId, out var ug))
                    forceCheckouts.Add((ug, x.v.VenueGuid, "inactive"));
            }
        }

        // 2. Expired Event venues — plus self-heal orphans (Closed with no Owner) so
        //    the sweep can recover from a prior interrupted close that left a leaked row.
        var expired = await db.Venues
            .Where(v => v.Type == VenueType.Event
                        && ((v.Status == VenueStatus.Active
                             && v.StartsAt != null
                             && v.DurationHours != null
                             && v.StartsAt.Value.AddHours((double)v.DurationHours.Value) < now)
                            || (v.Status == VenueStatus.Closed && v.OwnerId == null)))
            .ToListAsync(ct);

        // Determine soft vs hard close UPFRONT so we don't mutate Status on rows that
        // are about to be hard-deleted. (Historical bug: Status=Closed was persisted
        // first; if the subsequent hard-delete failed, the row was leaked as an orphan
        // because the sweep filter required Status=Active.)
        var ownerIdsUp = expired.Where(v => v.OwnerId.HasValue).Select(v => v.OwnerId!.Value).Distinct().ToList();
        var ownerLookup = ownerIdsUp.Count > 0
            ? await db.VenueOwners
                .Where(o => ownerIdsUp.Contains(o.Id))
                .Select(o => new { o.Id, o.CreateUserId })
                .ToDictionaryAsync(o => o.Id, o => o.CreateUserId, ct)
            : new Dictionary<long, long>();

        var hardDeleteVenueIds = new HashSet<long>();
        foreach (var v in expired)
        {
            bool isSoftClose = v.OwnerId.HasValue
                               && ownerLookup.TryGetValue(v.OwnerId.Value, out var ownerCreatorId)
                               && ownerCreatorId == v.CreateUserId;
            if (!isSoftClose)
                hardDeleteVenueIds.Add(v.Id);
        }

        foreach (var v in expired)
        {
            // Only mutate Status for venues that will survive (soft-close path).
            // Hard-delete venues are removed below regardless of Status.
            if (!hardDeleteVenueIds.Contains(v.Id))
                v.Status = VenueStatus.Closed;

            var actives = await db.VenueMemberships
                .Where(m => m.VenueId == v.Id)
                .Select(m => new { m.Id, m.UserId })
                .ToListAsync(ct);

            if (actives.Count > 0)
            {
                var userIds = actives.Select(m => m.UserId).Distinct().ToList();
                var userLookup = await db.Users
                    .Where(u => userIds.Contains(u.Id))
                    .Select(u => new { u.Id, u.UserGuid })
                    .ToDictionaryAsync(u => u.Id, u => u.UserGuid, ct);

                foreach (var m in actives)
                {
                    if (userLookup.TryGetValue(m.UserId, out var ug))
                        forceCheckouts.Add((ug, v.VenueGuid, "venueClosed"));
                }
            }

            affectedVenueIds.Add(v.Id);
            venueMatchEnds.Add(v.Id);
        }

        if (inactiveGlobals.Count == 0 && expired.Count == 0) return;

        // Hard-delete memberships.
        if (inactiveMembershipIds.Count > 0)
            await db.VenueMemberships
                .Where(m => inactiveMembershipIds.Contains(m.Id))
                .ExecuteDeleteAsync(ct);

        foreach (var venueId in venueMatchEnds)
            await db.VenueMemberships.Where(m => m.VenueId == venueId).ExecuteDeleteAsync(ct);

        // Update expired venue statuses.
        if (expired.Count > 0)
            await db.SaveChangesAsync(ct);

        // Delete swipes and ambient swipes for individually checked-out users.
        foreach (var (userId, venueId) in membershipMatchEnds)
        {
            await db.Swipes
                .Where(s => (s.FromUserId == userId || s.ToUserId == userId) && s.VenueId == venueId)
                .ExecuteDeleteAsync(ct);
            await db.AmbientSwipes
                .Where(s => s.FromUserId == userId && s.VenueId == venueId)
                .ExecuteDeleteAsync(ct);
        }

        // Delete all swipes for closed event venues.
        foreach (var venueId in venueMatchEnds)
        {
            await db.Swipes.Where(s => s.VenueId == venueId).ExecuteDeleteAsync(ct);
            await db.AmbientSwipes.Where(s => s.VenueId == venueId).ExecuteDeleteAsync(ct);
        }

        foreach (var (userId, venueId) in membershipMatchEnds)
            await matches.EndMembershipMatchesAsync(userId, venueId, MatchEndReason.UserLeft, ct);

        foreach (var venueId in venueMatchEnds)
            await matches.EndVenueMatchesAsync(venueId, MatchEndReason.VenueClosed, ct);

        // Broadcast presence updates.
        if (affectedVenueIds.Count > 0)
        {
            var venueGuids = await db.Venues
                .Where(v => affectedVenueIds.Contains(v.Id))
                .Select(v => new { v.Id, v.VenueGuid })
                .ToListAsync(ct);

            foreach (var vg in venueGuids)
            {
                var count = await db.VenueMemberships.CountAsync(m => m.VenueId == vg.Id, ct);
                var bucket = DensityBucket.From(count);
                await _hub.Clients.Group($"venue_{vg.VenueGuid}").SendAsync(
                    "PresenceUpdated",
                    new { venueGuid = vg.VenueGuid, densityBucket = bucket },
                    ct);
            }
        }

        foreach (var (userGuid, venueGuid, reason) in forceCheckouts)
        {
            await _hub.Clients.User(userGuid.ToString()).SendAsync(
                "ForceCheckout",
                new { venueGuid, reason },
                ct);

            if (!tracker.IsConnected(userGuid))
            {
                PushHelpers.TryPushCheckout(push, _logger, userGuid, venueGuid, reason);
            }
        }

        // ── Post-close: log and hard/soft delete expired event venues ─────
        if (expired.Count > 0)
        {
            // ownerLookup and hardDeleteVenueIds were computed upfront above.

            // Collect creator name lookup
            var creatorUserIds = expired.Select(v => v.CreateUserId).Distinct().ToList();
            var creatorNames = await db.Users
                .Where(u => creatorUserIds.Contains(u.Id))
                .Select(u => new { u.Id, u.DisplayName })
                .ToDictionaryAsync(u => u.Id, u => u.DisplayName, ct);

            // Collect stats lookup
            var expiredVenueIds = expired.Select(v => v.Id).ToList();
            var statsLookup = await db.VenueStats
                .Where(s => expiredVenueIds.Contains(s.VenueId))
                .ToDictionaryAsync(s => s.VenueId, ct);

            foreach (var v in expired)
            {
                if (v.OwnerId.HasValue)
                {
                    // Log to VenueOwnerEventLog
                    statsLookup.TryGetValue(v.Id, out var stats);
                    creatorNames.TryGetValue(v.CreateUserId, out var creatorName);

                    db.VenueOwnerEventLogs.Add(new VenueOwnerEventLog
                    {
                        VenueOwnerId = v.OwnerId.Value,
                        VenueId = v.Id,
                        Name = v.Name,
                        Description = v.Description,
                        StartsAt = v.StartsAt,
                        DurationHours = v.DurationHours,
                        EventType = v.EventType.ToString(),
                        JoinedCount = stats?.JoinedCount ?? 0,
                        MatchesCount = stats?.MatchesCount ?? 0,
                        ViewsCount = stats?.ViewsCount ?? 0,
                        CreateUserName = creatorName ?? string.Empty,
                        ClosedAt = DateTime.UtcNow,
                    });

                    // Delete VenueStats always for OwnerId events
                    await db.VenueStats.Where(s => s.VenueId == v.Id).ExecuteDeleteAsync(ct);
                }
            }

            if (hardDeleteVenueIds.Count > 0)
            {
                await db.VenueAmbientAssignments.Where(a => hardDeleteVenueIds.Contains(a.VenueId)).ExecuteDeleteAsync(ct);
                var hardMatchIds = await db.Matches
                    .Where(m => hardDeleteVenueIds.Contains(m.VenueId))
                    .Select(m => m.Id)
                    .ToListAsync(ct);
                if (hardMatchIds.Count > 0)
                    await db.ChatMessages.Where(c => hardMatchIds.Contains(c.MatchId)).ExecuteDeleteAsync(ct);
                await db.Matches.Where(m => hardDeleteVenueIds.Contains(m.VenueId)).ExecuteDeleteAsync(ct);
                await db.VenueStats.Where(s => hardDeleteVenueIds.Contains(s.VenueId)).ExecuteDeleteAsync(ct);
                await db.VenuePhotos.Where(p => hardDeleteVenueIds.Contains(p.VenueId)).ExecuteDeleteAsync(ct);
                await db.Venues.Where(v => hardDeleteVenueIds.Contains(v.Id)).ExecuteDeleteAsync(ct);
            }

            // Clean up all event data for soft-close venues (venue + photo stay as template)
            var softCloseVenueIds = expired
                .Where(v => v.OwnerId.HasValue && !hardDeleteVenueIds.Contains(v.Id))
                .Select(v => v.Id)
                .ToList();
            if (softCloseVenueIds.Count > 0)
            {
                await db.VenueAmbientAssignments
                    .Where(a => softCloseVenueIds.Contains(a.VenueId))
                    .ExecuteDeleteAsync(ct);
                var softMatchIds = await db.Matches
                    .Where(m => softCloseVenueIds.Contains(m.VenueId))
                    .Select(m => m.Id)
                    .ToListAsync(ct);
                if (softMatchIds.Count > 0)
                    await db.ChatMessages.Where(c => softMatchIds.Contains(c.MatchId)).ExecuteDeleteAsync(ct);
                await db.Matches.Where(m => softCloseVenueIds.Contains(m.VenueId)).ExecuteDeleteAsync(ct);
            }

            await db.SaveChangesAsync(ct);
        }
    }
}
