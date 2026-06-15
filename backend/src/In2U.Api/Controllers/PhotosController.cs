using In2U.Api.Data;
using In2U.Api.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Route("api/v1/photos")]
public sealed class PhotosController : ControllerBase
{
    private readonly AppDbContext _db;

    // Nice Earth SVG for Global venue
    private static readonly byte[] GlobalVenueSvg = System.Text.Encoding.UTF8.GetBytes("""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
          <defs>
            <linearGradient id="sky" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" style="stop-color:#1a1a2e"/>
              <stop offset="100%" style="stop-color:#16213e"/>
            </linearGradient>
            <linearGradient id="earth" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" style="stop-color:#4facfe"/>
              <stop offset="50%" style="stop-color:#00f2fe"/>
              <stop offset="100%" style="stop-color:#4facfe"/>
            </linearGradient>
            <linearGradient id="land" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" style="stop-color:#56ab2f"/>
              <stop offset="100%" style="stop-color:#a8e063"/>
            </linearGradient>
          </defs>
          <rect width="512" height="512" fill="url(#sky)"/>
          <circle cx="256" cy="256" r="180" fill="url(#earth)" opacity="0.9"/>
          <ellipse cx="200" cy="180" rx="60" ry="40" fill="url(#land)" opacity="0.8"/>
          <ellipse cx="300" cy="220" rx="80" ry="50" fill="url(#land)" opacity="0.8"/>
          <ellipse cx="220" cy="300" rx="50" ry="35" fill="url(#land)" opacity="0.8"/>
          <ellipse cx="320" cy="320" rx="40" ry="25" fill="url(#land)" opacity="0.8"/>
          <circle cx="256" cy="256" r="180" fill="none" stroke="#fff" stroke-width="3" opacity="0.3"/>
          <circle cx="150" cy="120" r="2" fill="#fff" opacity="0.8"/>
          <circle cx="400" cy="100" r="1.5" fill="#fff" opacity="0.6"/>
          <circle cx="80" cy="200" r="1" fill="#fff" opacity="0.5"/>
          <circle cx="450" cy="300" r="2" fill="#fff" opacity="0.7"/>
          <circle cx="100" cy="400" r="1.5" fill="#fff" opacity="0.6"/>
          <circle cx="420" cy="420" r="1" fill="#fff" opacity="0.5"/>
        </svg>
        """);

    public PhotosController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet("{userGuid:guid}")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> Get(Guid userGuid, CancellationToken ct)
    {
        var user = await _db.Users
            .Where(u => u.UserGuid == userGuid && !u.IsDeleted)
            .Select(u => new { u.Id })
            .FirstOrDefaultAsync(ct);
        if (user is null) return NotFound();

        var photo = await _db.UserPhotos
            .Where(p => p.UserId == user.Id)
            .Select(p => new { p.Data, p.ContentType })
            .FirstOrDefaultAsync(ct);
        if (photo is null) return NotFound();

        Response.Headers.CacheControl = "no-store";
        return File(photo.Data, photo.ContentType);
    }

    [HttpGet("venue/{venueGuid:guid}")]
    [ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
    public async Task<IActionResult> GetVenuePhoto(Guid venueGuid, CancellationToken ct)
    {
        var venue = await _db.Venues
            .Where(v => v.VenueGuid == venueGuid)
            .Select(v => new { v.Id, v.Type })
            .FirstOrDefaultAsync(ct);
        if (venue is null) return NotFound();

        var photo = await _db.VenuePhotos
            .Where(p => p.VenueId == venue.Id)
            .Select(p => new { p.Data, p.ContentType })
            .FirstOrDefaultAsync(ct);

        // Return default Earth image for Global venue
        if (photo is null)
        {
            if (venue.Type == VenueType.Global)
            {
                Response.Headers.CacheControl = "public, max-age=86400";
                return File(GlobalVenueSvg, "image/svg+xml");
            }
            return NotFound();
        }

        Response.Headers.CacheControl = "no-store";
        return File(photo.Data, photo.ContentType);
    }

    [HttpGet("owner/{ownerGuid:guid}")]
    [ResponseCache(Duration = 3600, Location = ResponseCacheLocation.Any)]
    public async Task<IActionResult> GetOwnerPhoto(Guid ownerGuid, CancellationToken ct)
    {
        var owner = await _db.VenueOwners
            .Where(o => o.VenueOwnerGuid == ownerGuid)
            .Select(o => new { o.Id })
            .FirstOrDefaultAsync(ct);
        if (owner is null) return NotFound();

        var photo = await _db.VenueOwnerPhotos
            .Where(p => p.VenueOwnerId == owner.Id)
            .Select(p => new { p.Data, p.ContentType })
            .FirstOrDefaultAsync(ct);
        if (photo is null) return NotFound();

        Response.Headers.CacheControl = "public, max-age=3600";
        return File(photo.Data, photo.ContentType);
    }
}
