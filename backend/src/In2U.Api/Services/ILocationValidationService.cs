using In2U.Api.Dtos.Venues;

namespace In2U.Api.Services;

public interface ILocationValidationService
{
    Task<LocationUpdateResponse> UpdateAsync(long userId, Guid venueGuid, double lat, double lng, CancellationToken ct = default);
    Task<bool> ForceCheckoutActiveAsync(long userId, string reason, CancellationToken ct = default);
}
