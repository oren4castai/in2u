using In2U.Api.Data;
using In2U.Api.Dtos.Admin;
using In2U.Api.Dtos.Owners;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize(Policy = "Admin")]
[Route("api/v1/admin/venue-claims")]
public sealed class AdminVenueClaimsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IVenueOwnershipService _ownership;

    public AdminVenueClaimsController(AppDbContext db, IVenueOwnershipService ownership)
    {
        _db = db;
        _ownership = ownership;
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<AdminVenueClaimDto>>> ListAll(
        [FromQuery] string? status,
        [FromQuery] string? search,
        CancellationToken ct)
    {
        var q = _db.VenueOwnershipClaims.AsQueryable();

        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<In2U.Api.Entities.ClaimStatus>(status, true, out var parsed))
            q = q.Where(c => c.Status == parsed);

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            q = q.Where(c =>
                c.Name.ToLower().Contains(s) ||
                c.ContactName.ToLower().Contains(s) ||
                c.ContactPhone.ToLower().Contains(s));
        }

        var claims = await q
            .OrderByDescending(c => c.CreatedAt)
            .Take(200)
            .Select(c => new AdminVenueClaimDto(
                c.ClaimGuid,
                c.Name,
                c.ContactName,
                c.ContactPhone,
                c.Lat,
                c.Lng,
                c.RadiusM,
                c.Status.ToString(),
                c.AdminNote,
                c.CreatedAt))
            .ToListAsync(ct);

        return Ok(claims);
    }

    [HttpGet("pending")]
    public async Task<ActionResult<IReadOnlyList<PendingClaimDto>>> ListPending(CancellationToken ct)
    {
        var claims = await _ownership.ListPendingClaimsAsync(ct);
        return Ok(claims);
    }

    [HttpPost("{claimGuid:guid}/approve")]
    public async Task<IActionResult> Approve(Guid claimGuid, CancellationToken ct)
    {
        var result = await _ownership.ApproveClaimAsync(claimGuid, ct);
        return result switch
        {
            ClaimActionResult.Ok => NoContent(),
            ClaimActionResult.NotFound => NotFound(),
            ClaimActionResult.NotPending => Conflict(new { message = "Claim is not pending." }),
            _ => StatusCode(500),
        };
    }

    [HttpPost("{claimGuid:guid}/reject")]
    public async Task<IActionResult> Reject(Guid claimGuid, [FromBody] RejectClaimRequest req, CancellationToken ct)
    {
        var result = await _ownership.RejectClaimAsync(claimGuid, req?.Note, ct);
        return result switch
        {
            ClaimActionResult.Ok => NoContent(),
            ClaimActionResult.NotFound => NotFound(),
            ClaimActionResult.NotPending => Conflict(new { message = "Claim is not pending." }),
            _ => StatusCode(500),
        };
    }

    [HttpDelete("{claimGuid:guid}")]
    public async Task<IActionResult> Delete(Guid claimGuid, CancellationToken ct)
    {
        var deleted = await _db.VenueOwnershipClaims
            .Where(c => c.ClaimGuid == claimGuid)
            .ExecuteDeleteAsync(ct);
        return deleted > 0 ? NoContent() : NotFound();
    }
}
