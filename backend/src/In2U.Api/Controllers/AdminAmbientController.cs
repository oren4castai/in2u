using In2U.Api.Dtos.Ambient;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize(Policy = "Admin")]
[Route("api/v1/admin/ambient")]
public sealed class AdminAmbientController : ControllerBase
{
    private readonly IAmbientProfileService _ambient;

    public AdminAmbientController(IAmbientProfileService ambient)
    {
        _ambient = ambient;
    }

    [HttpPost("replace")]
    public async Task<IActionResult> Replace([FromBody] AmbientReplaceRequest req, CancellationToken ct)
    {
        if (req is null || req.Profiles is null)
            return BadRequest(new { error = "profiles is required." });
        await _ambient.ReplaceCatalogAsync(req.Profiles, ct);
        return NoContent();
    }

    [HttpPost("rotate")]
    public async Task<IActionResult> Rotate(CancellationToken ct)
    {
        await _ambient.RotateAllAsync(ct);
        return NoContent();
    }
}
