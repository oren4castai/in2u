using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Venues;
using In2U.Api.Entities;
using In2U.Api.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace In2U.Api.Services;

public sealed class LocationValidationService : ILocationValidationService
{
    private readonly AppDbContext _db;
    private readonly IGeoMembershipTracker _tracker;
    private readonly IHubContext<VenueHub> _hub;
    private readonly IMatchService _matches;
    private readonly IPushService _push;
    private readonly ILogger<LocationValidationService> _log;
    private readonly GeoOptions _geo;

    public LocationValidationService(
        AppDbContext db,
        IGeoMembershipTracker tracker,
        IHubContext<VenueHub> hub,
        IMatchService matches,
        IPushService push,
        ILogger<LocationValidationService> log,
        IOptions<GeoOptions> geoOpts)
    {
        _db = db;
        _tracker = tracker;
        _hub = hub;
        _matches = matches;
        _push = push;
        _log = log;
        _geo = geoOpts.Value;
    }

    public async Task<LocationUpdateResponse> UpdateAsync(
        long userId, Guid venueGuid, double lat, double lng, CancellationToken ct = default)
    {
        var membership = await _db.VenueMemberships
            .Where(m => m.UserId == userId)
            .Join(_db.Venues, m => m.VenueId, v => v.Id, (m, v) => new { m, v })
            .Where(x => x.v.VenueGuid == venueGuid)
            .FirstOrDefaultAsync(ct);

        if (membership is null)
            throw new InvalidOperationException("Not checked in to this venue.");

        var m = membership.m;
        var v = membership.v;

        if (v.Status != VenueStatus.Active)
        {
            await AutoCheckoutAsync(m, v, "venueClosed", ct);
            throw new InvalidOperationException("Venue is not active.");
        }

        // Event venues: no per-update location tracking.
        if (v.Type != VenueType.Global)
            return new LocationUpdateResponse();

        var now = DateTime.UtcNow;

        // Inactive timeout (Global only).
        if (m.LastLocationAt != default
            && (now - m.LastLocationAt) > TimeSpan.FromMinutes(_geo.GlobalInactiveTimeoutMinutes))
        {
            await AutoCheckoutAsync(m, v, "inactive", ct);
            throw new InactiveTimeoutException("You were inactive too long; please check in again.");
        }

        m.LastLat = lat;
        m.LastLng = lng;
        m.LastLocationAt = now;
        await _db.SaveChangesAsync(ct);
        return new LocationUpdateResponse();
    }

    public async Task<bool> ForceCheckoutActiveAsync(long userId, string reason, CancellationToken ct = default)
    {
        var membership = await _db.VenueMemberships
            .Where(m => m.UserId == userId)
            .Join(_db.Venues, m => m.VenueId, v => v.Id, (m, v) => new { m, v })
            .FirstOrDefaultAsync(ct);

        if (membership is null) return false;

        await AutoCheckoutAsync(membership.m, membership.v, reason, ct);
        return true;
    }

    private async Task AutoCheckoutAsync(VenueMembership m, Venue v, string reason, CancellationToken ct)
    {
        await _db.VenueMemberships
            .Where(x => x.Id == m.Id)
            .ExecuteDeleteAsync(ct);
        await _db.Swipes
            .Where(s => (s.FromUserId == m.UserId || s.ToUserId == m.UserId) && s.VenueId == v.Id)
            .ExecuteDeleteAsync(ct);
        await _db.AmbientSwipes
            .Where(s => s.FromUserId == m.UserId && s.VenueId == v.Id)
            .ExecuteDeleteAsync(ct);

        await _matches.EndMembershipMatchesAsync(m.UserId, v.Id, MatchEndReason.UserLeft, ct);

        var userGuid = await _db.Users
            .Where(u => u.Id == m.UserId)
            .Select(u => u.UserGuid)
            .FirstOrDefaultAsync(ct);

        if (userGuid != Guid.Empty)
        {
            await _hub.Clients.User(userGuid.ToString()).SendAsync(
                "ForceCheckout",
                new { venueGuid = v.VenueGuid, reason },
                ct);

            if (!_tracker.IsConnected(userGuid))
            {
                PushHelpers.TryPushCheckout(_push, _log, userGuid, v.VenueGuid, reason);
            }
        }

        var count = await _db.VenueMemberships
            .CountAsync(x => x.VenueId == v.Id, ct);
        var bucket = DensityBucket.From(count);
        await _hub.Clients.Group($"venue_{v.VenueGuid}").SendAsync(
            "PresenceUpdated",
            new { venueGuid = v.VenueGuid, densityBucket = bucket },
            ct);
    }
}
