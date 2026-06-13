using In2U.Api.Data;
using In2U.Api.Dtos.Owners;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/venue-claims")]
public sealed class VenueClaimsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IVenueOwnershipService _ownership;

    public VenueClaimsController(AppDbContext db, IVenueOwnershipService ownership)
    {
        _db = db;
        _ownership = ownership;
    }

    [HttpPost]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<ActionResult<SubmitClaimResponse>> Submit(
        [FromForm] string name,
        [FromForm] string contactName,
        [FromForm] string contactPhone,
        [FromForm] double lat,
        [FromForm] double lng,
        [FromForm] int radiusM,
        IFormFile file,
        CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            return BadRequest(new { message = "A venue photo is required." });

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

        using var inputStream = file.OpenReadStream();
        using var image = await Image.LoadAsync(inputStream, ct);
        if (image.Width > 900 || image.Height > 900)
        {
            var size = image.Width >= image.Height ? new Size(900, 0) : new Size(0, 900);
            image.Mutate(x => x.Resize(new ResizeOptions { Size = size, Mode = ResizeMode.Max }));
        }

        using var ms = new MemoryStream();
        await image.SaveAsJpegAsync(ms, new SixLabors.ImageSharp.Formats.Jpeg.JpegEncoder { Quality = 78 }, ct);
        var bytes = ms.ToArray();

        var result = await _ownership.SubmitClaimAsync(
            userId.Value, name, contactName, contactPhone, lat, lng, radiusM, bytes, "image/jpeg", ct);
        if (!result.IsSuccess)
            return BadRequest(new { message = result.Error });

        return Ok(result.Value);
    }

    [HttpGet("mine")]
    public async Task<ActionResult<IReadOnlyList<MyClaimDto>>> Mine(CancellationToken ct)
    {
        var callerGuid = User.GetUserGuid();
        if (callerGuid is null) return Unauthorized();

        var userId = await _db.Users
            .Where(u => u.UserGuid == callerGuid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null) return Unauthorized();

        var claims = await _ownership.ListMyClaimsAsync(userId.Value, ct);
        return Ok(claims);
    }
}
