using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Swipes;
using In2U.Api.Dtos.Venues;
using In2U.Api.Entities;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/venues")]
public sealed class VenuesController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IVenueService _venues;
    private readonly ILocationValidationService _location;
    private readonly ISwipeService _swipes;

    public VenuesController(
        AppDbContext db,
        IVenueService venues,
        ILocationValidationService location,
        ISwipeService swipes)
    {
        _db = db;
        _venues = venues;
        _location = location;
        _swipes = swipes;
    }

    private async Task<(long UserId, Guid UserGuid)?> ResolveAsync(CancellationToken ct)
    {
        var guid = User.GetUserGuid();
        if (guid is null) return null;
        var id = await _db.Users
            .Where(u => u.UserGuid == guid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (id is null) return null;
        return (id.Value, guid.Value);
    }

    [HttpGet("discover")]
    public async Task<ActionResult<IReadOnlyList<DiscoverVenueDto>>> Discover(
        [FromQuery] double lat,
        [FromQuery] double lng,
        [FromQuery] int radiusM = 2000,
        [FromQuery] EventCategory? category = null,
        CancellationToken ct = default)
    {
        var list = await _venues.DiscoverAsync(lat, lng, radiusM, 50, category, ct);
        return Ok(list);
    }

    [HttpGet("{venueGuid:guid}")]
    public async Task<ActionResult<VenueDetailsDto>> Get(
        Guid venueGuid,
        [FromQuery] double? lat,
        [FromQuery] double? lng,
        CancellationToken ct)
    {
        var dto = await _venues.GetByGuidAsync(venueGuid, lat, lng, ct);
        if (dto is null) return NotFound();
        return Ok(dto);
    }

    [HttpGet("by-code/{code}")]
    public async Task<IActionResult> GetByShareCode(string code, [FromQuery] double? lat, [FromQuery] double? lng, CancellationToken ct)
    {
        // Validate code format (8 alphanumeric chars)
        if (string.IsNullOrWhiteSpace(code) || code.Length != 8)
            return BadRequest(new { message = "Invalid share code format." });

        // Ensure user is authenticated
        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return Unauthorized();

        // Look up venue by share code (case-insensitive)
        var venue = await _db.Venues
            .Where(v => v.ShareCode.ToUpper() == code.ToUpper() && v.Status == VenueStatus.Active)
            .Select(v => new {
                v.Id,
                v.VenueGuid,
                v.Name,
                v.Description,
                v.Type,
                v.EventType,
                v.Lat,
                v.Lng,
                v.RadiusM,
                v.StartsAt,
                v.DurationHours,
                v.Status,
                v.HasPhoto
            })
            .FirstOrDefaultAsync(ct);

        if (venue is null)
            return NotFound(new { message = "Event not found or no longer active." });

        // Calculate distance if lat/lng provided
        double? distanceM = null;
        if (lat.HasValue && lng.HasValue)
            distanceM = GeoMath.DistanceMeters(lat.Value, lng.Value, venue.Lat, venue.Lng);

        // Return DTO similar to VenueDetailsDto
        return Ok(new {
            venueGuid = venue.VenueGuid,
            name = venue.Name,
            description = venue.Description,
            type = venue.Type.ToString(),
            eventType = venue.EventType.ToString(),
            lat = venue.Lat,
            lng = venue.Lng,
            radiusM = venue.RadiusM,
            startsAt = venue.StartsAt,
            durationHours = venue.DurationHours,
            status = venue.Status.ToString(),
            hasPhoto = venue.HasPhoto,
            distanceM = distanceM,
        });
    }

    [HttpPost("{venueGuid:guid}/checkin")]
    public async Task<ActionResult<CheckInResponse>> CheckIn(
        Guid venueGuid, [FromBody] CheckInRequest req, CancellationToken ct)
    {
        var user = await ResolveAsync(ct);
        if (user is null) return Unauthorized();
        var resp = await _venues.CheckInAsync(user.Value.UserId, user.Value.UserGuid, venueGuid, req.Lat, req.Lng, ct);
        return Ok(resp);
    }

    [HttpPost("{venueGuid:guid}/leave")]
    public async Task<IActionResult> Leave(Guid venueGuid, CancellationToken ct)
    {
        var user = await ResolveAsync(ct);
        if (user is null) return Unauthorized();
        await _venues.LeaveAsync(user.Value.UserId, user.Value.UserGuid, venueGuid, ct);
        return NoContent();
    }

    [HttpGet("me")]
    public async Task<ActionResult<CheckInResponse>> GetMyActive(CancellationToken ct)
    {
        var user = await ResolveAsync(ct);
        if (user is null) return Unauthorized();

        var active = await _db.VenueMemberships
            .Where(m => m.UserId == user.Value.UserId)
            .Join(_db.Venues, m => m.VenueId, v => v.Id,
                (m, v) => new CheckInResponse(m.MembershipGuid, v.VenueGuid, m.CheckedInAt))
            .FirstOrDefaultAsync(ct);

        if (active is null) return NoContent();
        return Ok(active);
    }

    [HttpPost("{venueGuid:guid}/location")]
    [EnableRateLimiting("location-user")]
    public async Task<ActionResult<LocationUpdateResponse>> Location(
        Guid venueGuid, [FromBody] LocationUpdateRequest req, CancellationToken ct)
    {
        var user = await ResolveAsync(ct);
        if (user is null) return Unauthorized();
        var resp = await _location.UpdateAsync(user.Value.UserId, venueGuid, req.Lat, req.Lng, ct);
        return Ok(resp);
    }

    [HttpGet("{venueGuid:guid}/feed")]
    public async Task<ActionResult<FeedResponse>> Feed(
        Guid venueGuid,
        [FromQuery] string? cursor,
        [FromQuery] int limit = 20,
        CancellationToken ct = default)
    {
        var user = await ResolveAsync(ct);
        if (user is null) return Unauthorized();
        var resp = await _swipes.GetFeedAsync(user.Value.UserId, venueGuid, cursor, limit, ct);
        return Ok(resp);
    }
}
