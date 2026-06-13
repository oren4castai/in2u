using In2U.Api.Data;
using In2U.Api.Dtos.Auth;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly IAuthService _auth;
    private readonly AppDbContext _db;
    private readonly ISessionPurgeService _sessionPurge;
    private readonly IEventResumeService _eventResume;

    public AuthController(
        IAuthService auth,
        AppDbContext db,
        ISessionPurgeService sessionPurge,
        IEventResumeService eventResume)
    {
        _auth = auth;
        _db = db;
        _sessionPurge = sessionPurge;
        _eventResume = eventResume;
    }

    [HttpPost("email/register")]
    [EnableRateLimiting("auth-ip")]
    public async Task<ActionResult<TokenResponse>> RegisterEmail([FromBody] RegisterRequest req, CancellationToken ct)
        => Ok(await _auth.RegisterEmailAsync(req.Email, req.Password, req.DisplayName, ct));

    [HttpPost("email/login")]
    [EnableRateLimiting("auth-ip")]
    public async Task<ActionResult<TokenResponse>> LoginEmail([FromBody] LoginRequest req, CancellationToken ct)
        => Ok(await _auth.LoginEmailAsync(req.Email, req.Password, ct));

    [HttpPost("oauth/google")]
    [EnableRateLimiting("auth-ip")]
    public async Task<ActionResult<TokenResponse>> LoginGoogle([FromBody] OAuthRequest req, CancellationToken ct)
        => Ok(await _auth.LoginGoogleAsync(req.IdToken, ct));

    [HttpPost("oauth/apple")]
    [EnableRateLimiting("auth-ip")]
    public IActionResult LoginApple([FromBody] OAuthRequest req)
        => Problem(statusCode: StatusCodes.Status501NotImplemented,
            title: "Not Implemented",
            detail: "Apple sign-in arrives in P5 polish");

    [HttpPost("refresh")]
    [EnableRateLimiting("auth-ip")]
    public async Task<ActionResult<TokenResponse>> Refresh([FromBody] RefreshRequest req, CancellationToken ct)
        => Ok(await _auth.RefreshAsync(req.RefreshToken, ct));

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        var guid = User.GetUserGuid();
        if (guid is null) return Unauthorized();

        var user = await _db.Users.FirstOrDefaultAsync(u => u.UserGuid == guid, ct);
        if (user is null) return Unauthorized();

        await _auth.LogoutAsync(user.Id, ct);
        return NoContent();
    }

    /// <summary>
    /// Called by the mobile client on app launch when the session is restored
    /// from a stored token (no manual login). Returns resumed=true when the user
    /// is eligible to resume an active event session; otherwise runs regular purge.
    /// </summary>
    [Authorize]
    [HttpPost("session-start")]
    public async Task<ActionResult<SessionStartResponse>> SessionStart(CancellationToken ct)
    {
        var guid = User.GetUserGuid();
        if (guid is null) return Unauthorized();

        var user = await _db.Users
            .Where(u => u.UserGuid == guid)
            .Select(u => new { u.Id })
            .FirstOrDefaultAsync(ct);
        if (user is null) return Unauthorized();

        var resumed = await _eventResume.IsEligibleAsync(user.Id, ct);
        if (!resumed)
            await _sessionPurge.PurgeSessionDataAsync(user.Id, ct);

        return Ok(new SessionStartResponse(resumed));
    }
}
