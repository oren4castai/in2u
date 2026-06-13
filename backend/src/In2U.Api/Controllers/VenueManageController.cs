using In2U.Api.Data;
using In2U.Api.Dtos.Venues;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/venues/{venueGuid:guid}/manage")]
public sealed class VenueManageController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IVenueService _venues;

    public VenueManageController(AppDbContext db, IVenueService venues)
    {
        _db = db;
        _venues = venues;
    }

    [HttpGet("stats")]
    public async Task<ActionResult<VenueStatsDto>> GetStats(Guid venueGuid, CancellationToken ct)
    {
        if (!await IsAuthorizedAsync(venueGuid, ct)) return Forbid();
        var dto = await _venues.GetStatsAsync(venueGuid, ct);
        return dto is null ? NotFound() : Ok(dto);
    }

    [HttpGet("participants")]
    public async Task<ActionResult<IReadOnlyList<VenueParticipantDto>>> GetParticipants(
        Guid venueGuid, [FromQuery] string? search, CancellationToken ct)
    {
        if (!await IsAuthorizedAsync(venueGuid, ct)) return Forbid();
        var list = await _venues.GetParticipantsAsync(venueGuid, search, ct);
        return Ok(list);
    }

    [HttpDelete("participants/{targetUserGuid:guid}")]
    public async Task<IActionResult> ForceCheckout(Guid venueGuid, Guid targetUserGuid, CancellationToken ct)
    {
        if (!await IsAuthorizedAsync(venueGuid, ct)) return Forbid();
        await _venues.ForceCheckoutParticipantAsync(venueGuid, targetUserGuid, ct);
        return NoContent();
    }

    private async Task<bool> IsAuthorizedAsync(Guid venueGuid, CancellationToken ct)
    {
        if (User.HasClaim("role", "Admin")) return true;

        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return false;

        var callerId = await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (callerId is null) return false;

        return await _db.Venues
            .AnyAsync(v => v.VenueGuid == venueGuid && v.CreateUserId == callerId.Value, ct);
    }
}
