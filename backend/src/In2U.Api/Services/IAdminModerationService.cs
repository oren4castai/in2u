using In2U.Api.Dtos.Admin;

namespace In2U.Api.Services;

public interface IAdminModerationService
{
    Task<AdminStatsDto> GetStatsAsync(CancellationToken ct = default);
    Task<IReadOnlyList<AdminUserDto>> ListUsersAsync(string? search, CancellationToken ct = default);
    Task<IReadOnlyList<AdminVenueDto>> ListVenuesAsync(string? search, CancellationToken ct = default);
    Task<IReadOnlyList<AdminEventDto>> ListEventsAsync(string? search, CancellationToken ct = default);
    Task<bool> DeleteVenueHardAsync(Guid venueGuid, CancellationToken ct = default);
    Task<bool> DeleteEventHardAsync(Guid venueGuid, CancellationToken ct = default);
    Task<bool> DeleteUserHardAsync(Guid userGuid, CancellationToken ct = default);
}
