using In2U.Api.Data;
using In2U.Api.Dtos.Auth;
using In2U.Api.Entities;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/me")]
public sealed class MeController : ControllerBase
{
    private readonly AppDbContext _db;

    public MeController(AppDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<ActionResult<UserDto>> Get(CancellationToken ct)
    {
        var user = await LoadAsync(ct);
        if (user is null) return Unauthorized();
        return Ok(AuthService.MapUser(user));
    }

    [HttpPatch]
    public async Task<ActionResult<UserDto>> Patch([FromBody] UpdateMeRequest req, CancellationToken ct)
    {
        var user = await LoadAsync(ct);
        if (user is null) return Unauthorized();

        if (req.DisplayName is not null)
        {
            var name = req.DisplayName.Trim();
            if (string.IsNullOrEmpty(name))
                throw new ArgumentException("DisplayName cannot be empty.");
            user.DisplayName = name;
        }

        if (req.Bio is not null)
            user.Bio = req.Bio;

        if (req.BirthYear is not null)
            user.BirthYear = req.BirthYear;

        if (req.Gender is not null)
        {
            if (!Enum.TryParse<Gender>(req.Gender, ignoreCase: true, out var g))
                throw new ArgumentException("Invalid gender value.");
            user.Gender = g;
        }

        if (req.PreferGender is not null)
        {
            if (!Enum.TryParse<GenderPreference>(req.PreferGender, ignoreCase: true, out var pg))
                throw new ArgumentException("Invalid preferGender value.");
            user.PreferGender = pg;
        }

        await _db.SaveChangesAsync(ct);
        return Ok(AuthService.MapUser(user));
    }

    [HttpDelete]
    public async Task<IActionResult> Delete(CancellationToken ct)
    {
        var user = await LoadAsync(ct);
        if (user is null) return Unauthorized();

        user.IsDeleted = true;
        user.PasswordHash = null;
        user.RefreshTokenHash = null;
        user.RefreshTokenExpiresAt = null;
        user.Bio = null;
        user.HasPhoto = false;
        user.Email = $"deleted_{user.Id}@in2u.local";
        user.DisplayName = "deleted";

        await _db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost("photo")]
    [RequestSizeLimit(10 * 1024 * 1024)] // 10 MB max
    public async Task<ActionResult<UserDto>> UploadPhoto(IFormFile file, CancellationToken ct)
    {
        if (file is null || file.Length == 0)
            throw new ArgumentException("No file provided.");

        var mime = file.ContentType.ToLowerInvariant();
        if (mime != "image/jpeg" && mime != "image/png" && mime != "image/webp")
            throw new ArgumentException("Only JPEG, PNG, or WebP images are accepted.");

        var user = await LoadAsync(ct);
        if (user is null) return Unauthorized();

        using var inputStream = file.OpenReadStream();
        using var image = await SixLabors.ImageSharp.Image.LoadAsync(inputStream, ct);

        // Resize to max 900px on longest side, maintaining aspect ratio
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

        var existing = await _db.UserPhotos.FirstOrDefaultAsync(p => p.UserId == user.Id, ct);
        if (existing is not null)
        {
            existing.Data = bytes;
            existing.ContentType = "image/jpeg";
            existing.UpdatedAt = DateTime.UtcNow;
        }
        else
        {
            _db.UserPhotos.Add(new In2U.Api.Entities.UserPhoto
            {
                UserId = user.Id,
                Data = bytes,
                ContentType = "image/jpeg",
                UpdatedAt = DateTime.UtcNow,
            });
        }

        user.HasPhoto = true;
        await _db.SaveChangesAsync(ct);
        return Ok(AuthService.MapUser(user));
    }

    [HttpDelete("photo")]
    public async Task<ActionResult<UserDto>> DeletePhoto(CancellationToken ct)
    {
        var user = await LoadAsync(ct);
        if (user is null) return Unauthorized();

        await _db.UserPhotos.Where(p => p.UserId == user.Id).ExecuteDeleteAsync(ct);
        user.HasPhoto = false;
        await _db.SaveChangesAsync(ct);
        return Ok(AuthService.MapUser(user));
    }

    private async Task<User?> LoadAsync(CancellationToken ct)
    {
        var guid = User.GetUserGuid();
        if (guid is null) return null;
        return await _db.Users.FirstOrDefaultAsync(u => u.UserGuid == guid && !u.IsDeleted, ct);
    }
}
