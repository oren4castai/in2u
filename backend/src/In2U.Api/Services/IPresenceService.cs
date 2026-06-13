namespace In2U.Api.Services;

public interface IPresenceService
{
    Task<int> ActiveMemberCountAsync(long venueId, CancellationToken ct = default);
    Task<string> DensityBucketAsync(long venueId, CancellationToken ct = default);
    Task BroadcastPresenceUpdatedAsync(long venueId, Guid venueGuid, CancellationToken ct = default);
}
