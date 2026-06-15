using In2U.Api.Dtos.Venues;
using In2U.Api.Entities;

namespace In2U.Api.Services;

public interface IVenueService
{
    Task<IReadOnlyList<DiscoverVenueDto>> DiscoverAsync(double lat, double lng, int radiusM, int limit = 50, EventCategory? category = null, CancellationToken ct = default);
    Task<VenueDetailsDto?> GetByGuidAsync(Guid venueGuid, double? originLat = null, double? originLng = null, CancellationToken ct = default);
    Task<CheckInResponse> CheckInAsync(long userId, Guid userGuid, Guid venueGuid, double lat, double lng, CancellationToken ct = default);
    Task LeaveAsync(long userId, Guid userGuid, Guid venueGuid, CancellationToken ct = default);
    Task<CreatedVenueDto> CreateAsync(CreateVenueRequest req, long createUserId, CancellationToken ct = default);
    Task<CloseVenueResponse> CloseAsync(Guid venueGuid, bool hardDelete = false, CancellationToken ct = default);
    Task<VenueStatsDto?> GetStatsAsync(Guid venueGuid, CancellationToken ct = default);
    Task<IReadOnlyList<VenueParticipantDto>> GetParticipantsAsync(Guid venueGuid, string? search, CancellationToken ct = default);
    Task ForceCheckoutParticipantAsync(Guid venueGuid, Guid targetUserGuid, CancellationToken ct = default);
    Task<IReadOnlyList<MyEventDto>> GetMyEventsAsync(long userId, CancellationToken ct = default);
    Task<MyEventDto?> PatchEventAsync(Guid venueGuid, PatchEventRequest req, CancellationToken ct = default);
}
