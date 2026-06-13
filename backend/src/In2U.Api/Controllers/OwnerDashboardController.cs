using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Owners;
using In2U.Api.Hubs;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/owner")]
public sealed class OwnerDashboardController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IVenueOwnershipService _ownership;
    private readonly IVenueService _venues;
    private readonly IPushService _push;
    private readonly IGeoMembershipTracker _tracker;
    private readonly IHubContext<VenueHub> _hub;
    private readonly ILogger<OwnerDashboardController> _log;

    public OwnerDashboardController(
        AppDbContext db,
        IVenueOwnershipService ownership,
        IVenueService venues,
        IPushService push,
        IGeoMembershipTracker tracker,
        IHubContext<VenueHub> hub,
        ILogger<OwnerDashboardController> log)
    {
        _db = db;
        _ownership = ownership;
        _venues = venues;
        _push = push;
        _tracker = tracker;
        _hub = hub;
        _log = log;
    }

    [HttpGet("venues")]
    public async Task<ActionResult<IReadOnlyList<OwnerVenueSummaryDto>>> ListVenues(CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();

        var venues = await _ownership.ListOwnedVenuesAsync(userId.Value, ct);
        return Ok(venues);
    }

    [HttpGet("venues/{ownerGuid:guid}")]
    public async Task<ActionResult<OwnerVenueDetailDto>> VenueDetail(Guid ownerGuid, CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();

        var detail = await _ownership.GetVenueDetailAsync(userId.Value, ownerGuid, ct);
        return detail is null ? NotFound() : Ok(detail);
    }

    [HttpPost("events/{venueGuid:guid}/pause")]
    public async Task<IActionResult> SetPaused(Guid venueGuid, [FromQuery] bool paused, CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();

        var result = await _ownership.SetEventPausedAsync(userId.Value, venueGuid, paused, ct);
        return MapEventAction(result);
    }

    [HttpDelete("events/{venueGuid:guid}")]
    public async Task<IActionResult> Delete(Guid venueGuid, CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();

        var verify = await _ownership.VerifyGovernedEventAsync(userId.Value, venueGuid, ct);
        if (verify != OwnerEventActionResult.Ok) return MapEventAction(verify);

        await _venues.CloseAsync(venueGuid, ct);
        return NoContent();
    }

    [HttpPost("events/{venueGuid:guid}/announcement")]
    public async Task<IActionResult> SendAnnouncement(
        Guid venueGuid,
        [FromBody] SendVenueAnnouncementRequest req,
        CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();

        var verify = await _ownership.VerifyGovernedEventAsync(userId.Value, venueGuid, ct);
        if (verify != OwnerEventActionResult.Ok) return MapEventAction(verify);

        var message = req.Message?.Trim();
        if (string.IsNullOrWhiteSpace(message))
            return BadRequest(new { message = "Message is required." });
        if (message.Length > 180)
            return BadRequest(new { message = "Message must be 180 characters or fewer." });

        var venue = await _db.Venues
            .Where(v => v.VenueGuid == venueGuid)
            .Select(v => new { v.Id, v.VenueGuid })
            .FirstOrDefaultAsync(ct);
        if (venue is null) return NotFound();

        var recipientGuids = await _db.VenueMemberships
            .Where(m => m.VenueId == venue.Id)
            .Join(_db.Users, m => m.UserId, u => u.Id, (m, u) => u.UserGuid)
            .Distinct()
            .ToListAsync(ct);

        await _hub.Clients.Group($"venue_{venue.VenueGuid}").SendAsync(
            "VenueAnnouncement",
            new
            {
                venueGuid = venue.VenueGuid,
                title = "Venue announcement",
                body = message,
            },
            ct);

        foreach (var recipientGuid in recipientGuids)
        {
            if (!_tracker.ShouldPush(recipientGuid)) continue;
            PushHelpers.TryPushVenueAnnouncement(_push, _log, recipientGuid, venue.VenueGuid, message);
        }

        return NoContent();
    }

    [HttpDelete("venues/{ownerGuid:guid}/past-events/{logId:long}")]
    public async Task<IActionResult> DeletePastEvent(Guid ownerGuid, long logId, CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();

        var deleted = await _ownership.DeletePastEventAsync(userId.Value, ownerGuid, logId, ct);
        return deleted ? NoContent() : NotFound();
    }

    [HttpDelete("venues/{ownerGuid:guid}")]
    public async Task<IActionResult> DeleteVenue(Guid ownerGuid, CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();

        var deleted = await _ownership.DeleteVenueAsync(userId.Value, ownerGuid, ct);
        return deleted ? NoContent() : NotFound();
    }

    private IActionResult MapEventAction(OwnerEventActionResult result) => result switch
    {
        OwnerEventActionResult.Ok => NoContent(),
        OwnerEventActionResult.NoOwner => Forbid(),
        OwnerEventActionResult.NotGoverned => Forbid(),
        OwnerEventActionResult.NotFound => NotFound(),
        _ => StatusCode(500),
    };

    private async Task<long?> ResolveUserIdAsync(CancellationToken ct)
    {
        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return null;
        return await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
    }
}
