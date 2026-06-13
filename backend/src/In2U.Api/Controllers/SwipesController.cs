using In2U.Api.Data;
using In2U.Api.Dtos.Swipes;
using In2U.Api.Entities;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/venues/{venueGuid:guid}/swipes")]
public sealed class SwipesController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly ISwipeService _swipes;

    public SwipesController(AppDbContext db, ISwipeService swipes)
    {
        _db = db;
        _swipes = swipes;
    }

    [HttpPost("{toUserGuid:guid}")]
    [EnableRateLimiting("swipes-user")]
    public async Task<ActionResult<SwipeResponse>> Swipe(
        Guid venueGuid, Guid toUserGuid, [FromBody] SwipeRequest req, CancellationToken ct)
    {
        if (req is null || string.IsNullOrWhiteSpace(req.Direction))
            return BadRequest(new { error = "direction is required." });

        SwipeDirection direction;
        switch (req.Direction.Trim().ToLowerInvariant())
        {
            case "left": direction = SwipeDirection.Left; break;
            case "right": direction = SwipeDirection.Right; break;
            default: return BadRequest(new { error = "direction must be 'left' or 'right'." });
        }

        var guid = User.GetUserGuid();
        if (guid is null) return Unauthorized();
        var userId = await _db.Users
            .Where(u => u.UserGuid == guid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null) return Unauthorized();

        var resp = await _swipes.RecordAsync(userId.Value, toUserGuid, venueGuid, direction, ct);
        return Ok(resp);
    }
}
