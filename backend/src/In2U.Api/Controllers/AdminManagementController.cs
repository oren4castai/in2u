using In2U.Api.Dtos.Admin;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize(Policy = "Admin")]
[Route("api/v1/admin")]
public sealed class AdminManagementController : ControllerBase
{
    private readonly IAdminModerationService _admin;

    public AdminManagementController(IAdminModerationService admin)
    {
        _admin = admin;
    }

    [HttpGet("stats")]
    public async Task<ActionResult<AdminStatsDto>> Stats(CancellationToken ct)
        => Ok(await _admin.GetStatsAsync(ct));

    [HttpGet("users")]
    public async Task<ActionResult<IReadOnlyList<AdminUserDto>>> Users([FromQuery] string? search, CancellationToken ct)
        => Ok(await _admin.ListUsersAsync(search, ct));

    [HttpDelete("users/{userGuid:guid}")]
    public async Task<IActionResult> DeleteUser(Guid userGuid, CancellationToken ct)
        => await _admin.DeleteUserHardAsync(userGuid, ct) ? NoContent() : NotFound();

    [HttpGet("venues")]
    public async Task<ActionResult<IReadOnlyList<AdminVenueDto>>> Venues([FromQuery] string? search, CancellationToken ct)
        => Ok(await _admin.ListVenuesAsync(search, ct));

    [HttpDelete("venues/{venueGuid:guid}")]
    public async Task<IActionResult> DeleteVenue(Guid venueGuid, CancellationToken ct)
        => await _admin.DeleteVenueHardAsync(venueGuid, ct) ? NoContent() : NotFound();

    [HttpGet("events")]
    public async Task<ActionResult<IReadOnlyList<AdminEventDto>>> Events([FromQuery] string? search, CancellationToken ct)
        => Ok(await _admin.ListEventsAsync(search, ct));

    [HttpDelete("events/{venueGuid:guid}")]
    public async Task<IActionResult> DeleteEvent(Guid venueGuid, CancellationToken ct)
        => await _admin.DeleteEventHardAsync(venueGuid, ct) ? NoContent() : NotFound();
}
