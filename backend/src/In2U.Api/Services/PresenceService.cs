using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Services;

public sealed class PresenceService : IPresenceService
{
    private readonly AppDbContext _db;
    private readonly IHubContext<VenueHub> _hub;

    public PresenceService(AppDbContext db, IHubContext<VenueHub> hub)
    {
        _db = db;
        _hub = hub;
    }

    public Task<int> ActiveMemberCountAsync(long venueId, CancellationToken ct = default) =>
        _db.VenueMemberships.CountAsync(m => m.VenueId == venueId, ct);

    public async Task<string> DensityBucketAsync(long venueId, CancellationToken ct = default)
    {
        var count = await ActiveMemberCountAsync(venueId, ct);
        return DensityBucket.From(count);
    }

    public async Task BroadcastPresenceUpdatedAsync(long venueId, Guid venueGuid, CancellationToken ct = default)
    {
        var bucket = await DensityBucketAsync(venueId, ct);
        await _hub.Clients.Group($"venue_{venueGuid}").SendAsync(
            "PresenceUpdated",
            new { venueGuid, densityBucket = bucket },
            ct);
    }
}
