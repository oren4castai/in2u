using In2U.Api.Data;
using In2U.Api.Dtos.Venues;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize(Policy = "Admin")]
[Route("api/v1/admin/venues")]
public sealed class AdminVenuesController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IVenueService _venues;

    public AdminVenuesController(AppDbContext db, IVenueService venues)
    {
        _db = db;
        _venues = venues;
    }

    [HttpPost]
    public async Task<ActionResult<CreatedVenueDto>> Create([FromBody] CreateVenueRequest req, CancellationToken ct)
    {
        var guid = User.GetUserGuid();
        if (guid is null) return Unauthorized();
        var ownerId = await _db.Users
            .Where(u => u.UserGuid == guid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (ownerId is null) return Unauthorized();

        var dto = await _venues.CreateAsync(req, ownerId.Value, ct);
        return Ok(dto);
    }

    [HttpPost("{venueGuid:guid}/close")]
    public async Task<ActionResult<CloseVenueResponse>> Close(Guid venueGuid, CancellationToken ct)
    {
        var dto = await _venues.CloseAsync(venueGuid, false, ct);
        return Ok(dto);
    }
}
