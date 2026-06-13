using In2U.Api.Data;
using In2U.Api.Common;
using In2U.Api.Dtos.Owners;
using In2U.Api.Dtos.Venues;
using In2U.Api.Entities;
using In2U.Api.Hubs;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/events")]
public sealed class EventsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IVenueService _venues;
    private readonly IVenueOwnershipService _ownership;
    private readonly IHubContext<VenueHub> _hub;
    private readonly OwnerOptions _owner;

    public EventsController(
        AppDbContext db,
        IVenueService venues,
        IVenueOwnershipService ownership,
        IHubContext<VenueHub> hub,
        IOptions<OwnerOptions> ownerOpts)
    {
        _db = db;
        _venues = venues;
        _ownership = ownership;
        _hub = hub;
        _owner = ownerOpts.Value;
    }

    [HttpPost]
    public async Task<ActionResult<CreatedVenueDto>> Create([FromBody] CreateEventRequest req, CancellationToken ct)
    {
        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return Unauthorized();

        var userId = await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null) return Unauthorized();

        var eventType = Enum.TryParse<VenueEventType>(req.EventType, ignoreCase: true, out var et)
            ? et
            : VenueEventType.Public;

        // Governance: events inside an approved owner region follow that owner's rules.
        var governance = await _ownership.EvaluateEventCreationAsync(
            req.Lat, req.Lng, eventType, userId.Value, ct);
        if (!governance.Allowed)
            return Conflict(new { message = governance.RejectMessage });

        var ownedOwnerIds = await _db.VenueOwners
            .Where(o => o.CreateUserId == userId.Value)
            .Select(o => o.Id)
            .ToListAsync(ct);

        var isOwnerMode = governance.OwnerId.HasValue && ownedOwnerIds.Contains(governance.OwnerId.Value);
        if (isOwnerMode)
        {
            var ownerId = governance.OwnerId!.Value;
            var ownerMaxActive = Math.Max(1, _owner.OwnerMaxActiveEvents);
            var ownerActiveCount = await _db.Venues.CountAsync(v =>
                v.CreateUserId == userId.Value &&
                v.Type == VenueType.Event &&
                v.Status == VenueStatus.Active &&
                v.OwnerId == ownerId, ct);

            if (ownerActiveCount >= ownerMaxActive)
                return Conflict(new { message = $"You can create up to {ownerMaxActive} active owner events in this venue." });
        }
        else
        {
            var hasRegularActive = await _db.Venues.AnyAsync(v =>
                v.CreateUserId == userId.Value &&
                v.Type == VenueType.Event &&
                v.Status == VenueStatus.Active &&
                (v.OwnerId == null || !ownedOwnerIds.Contains(v.OwnerId.Value)), ct);

            if (hasRegularActive)
                return Conflict(new { message = "You already have an active event." });
        }

        var venueReq = new CreateVenueRequest(
            req.Name,
            req.Description,
            "Event",
            req.EventType,
            req.Lat,
            req.Lng,
            req.RadiusM,
            req.StartsAt,
            req.DurationHours,
            governance.OwnerId,
            req.Category);

        var dto = await _venues.CreateAsync(venueReq, userId.Value, ct);

        // Governed events auto-inherit the owner's branding photo.
        if (governance.OwnerId is not null)
        {
            var venueId = await _db.Venues
                .Where(v => v.VenueGuid == dto.VenueGuid)
                .Select(v => v.Id)
                .FirstOrDefaultAsync(ct);
            if (venueId != 0)
                await _ownership.InheritOwnerPhotoAsync(governance.OwnerId.Value, venueId, ct);
        }

        return Ok(dto);
    }

    [HttpGet("mine")]
    public async Task<ActionResult<IReadOnlyList<MyEventDto>>> GetMine(CancellationToken ct)
    {
        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return Unauthorized();

        var userId = await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null) return Unauthorized();

        var events = await _venues.GetMyEventsAsync(userId.Value, ct);
        return Ok(events);
    }

    [HttpGet("governance")]
    public async Task<ActionResult<GovernancePreviewDto>> Governance(
        [FromQuery] double lat, [FromQuery] double lng, CancellationToken ct)
    {
        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return Unauthorized();

        var userId = await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null) return Unauthorized();

        var preview = await _ownership.PreviewGovernanceAsync(lat, lng, userId.Value, ct);
        return Ok(preview);
    }

    [HttpPatch("{venueGuid:guid}")]
    public async Task<ActionResult<MyEventDto>> Patch(Guid venueGuid, [FromBody] PatchEventRequest req, CancellationToken ct)
    {
        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return Unauthorized();

        var userId = await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null) return Unauthorized();

        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct);
        if (venue is null) return NotFound();

        var isAdmin = User.HasClaim("role", "Admin");
        if (!isAdmin && venue.CreateUserId != userId.Value) return Forbid();

        var result = await _venues.PatchEventAsync(venueGuid, req, ct);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPost("{venueGuid:guid}/photo")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult> UploadPhoto(Guid venueGuid, IFormFile file, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            return BadRequest(new { message = "No file provided." });

        var mime = file.ContentType.ToLowerInvariant();
        if (mime != "image/jpeg" && mime != "image/png" && mime != "image/webp")
            return BadRequest(new { message = "Only JPEG, PNG, or WebP images are accepted." });

        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return Unauthorized();

        var userId = await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null) return Unauthorized();

        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct);
        if (venue is null) return NotFound();

        var isAdmin = User.HasClaim("role", "Admin");
        if (!isAdmin && venue.CreateUserId != userId.Value) return Forbid();

        using var inputStream = file.OpenReadStream();
        using var image = await SixLabors.ImageSharp.Image.LoadAsync(inputStream, ct);

        if (image.Width > 900 || image.Height > 900)
        {
            var size = image.Width >= image.Height
                ? new SixLabors.ImageSharp.Size(900, 0)
                : new SixLabors.ImageSharp.Size(0, 900);
            image.Mutate(x => x.Resize(new SixLabors.ImageSharp.Processing.ResizeOptions
            {
                Size = size,
                Mode = SixLabors.ImageSharp.Processing.ResizeMode.Max,
            }));
        }

        using var ms = new System.IO.MemoryStream();
        await image.SaveAsJpegAsync(ms, new SixLabors.ImageSharp.Formats.Jpeg.JpegEncoder { Quality = 78 }, ct);
        var bytes = ms.ToArray();

        var existing = await _db.VenuePhotos.FirstOrDefaultAsync(p => p.VenueId == venue.Id, ct);
        if (existing is not null)
        {
            existing.Data = bytes;
            existing.ContentType = "image/jpeg";
            existing.UpdatedAt = DateTime.UtcNow;
        }
        else
        {
            _db.VenuePhotos.Add(new In2U.Api.Entities.VenuePhoto
            {
                VenueId = venue.Id,
                Data = bytes,
                ContentType = "image/jpeg",
                UpdatedAt = DateTime.UtcNow,
            });
        }

        venue.HasPhoto = true;
        await _db.SaveChangesAsync(ct);
        await _hub.Clients.All.SendAsync("EventListChanged", venueGuid, "updated", ct);
        return NoContent();
    }

    [HttpPost("{venueGuid:guid}/close")]
    public async Task<IActionResult> Close(Guid venueGuid, CancellationToken ct)
    {
        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return Unauthorized();

        var userId = await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null) return Unauthorized();

        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct);
        if (venue is null) return NotFound();

        var isAdmin = User.HasClaim("role", "Admin");
        if (!isAdmin && venue.CreateUserId != userId.Value) return Forbid();

        await _venues.CloseAsync(venueGuid, ct);
        return NoContent();
    }
}
