using In2U.Api.Data;
using In2U.Api.Dtos.Matches;
using In2U.Api.Entities;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/matches")]
public sealed class MatchesController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IMatchService _matches;

    public MatchesController(AppDbContext db, IMatchService matches)
    {
        _db = db;
        _matches = matches;
    }

    private async Task<long?> ResolveUserIdAsync(CancellationToken ct)
    {
        var guid = User.GetUserGuid();
        if (guid is null) return null;
        return await _db.Users
            .Where(u => u.UserGuid == guid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<MatchDto>>> List(CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();
        var list = await _matches.ListActiveForUserAsync(userId.Value, ct);
        return Ok(list);
    }

    [HttpDelete("{matchGuid:guid}")]
    public async Task<IActionResult> Unmatch(Guid matchGuid, CancellationToken ct)
    {
        var userId = await ResolveUserIdAsync(ct);
        if (userId is null) return Unauthorized();
        var ok = await _matches.EndMatchAsync(matchGuid, userId.Value, MatchEndReason.Unmatched, ct);
        return ok ? NoContent() : NotFound();
    }
}
