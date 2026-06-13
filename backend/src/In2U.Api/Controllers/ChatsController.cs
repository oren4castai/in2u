using In2U.Api.Data;
using In2U.Api.Dtos.Chats;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/matches/{matchGuid:guid}/messages")]
public sealed class ChatsController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IChatService _chats;

    public ChatsController(AppDbContext db, IChatService chats)
    {
        _db = db;
        _chats = chats;
    }

    private async Task<(long Id, Guid Guid)?> ResolveUserAsync(CancellationToken ct)
    {
        var guid = User.GetUserGuid();
        if (guid is null) return null;
        var id = await _db.Users
            .Where(u => u.UserGuid == guid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        return id is null ? null : (id.Value, guid.Value);
    }

    [HttpGet]
    public async Task<ActionResult<MessageHistoryResponse>> GetHistory(
        Guid matchGuid,
        [FromQuery] long? beforeId,
        [FromQuery] int limit = 50,
        CancellationToken ct = default)
    {
        var user = await ResolveUserAsync(ct);
        if (user is null) return Unauthorized();

        var clamped = Math.Clamp(limit, 1, 100);
        try
        {
            var result = await _chats.GetHistoryAsync(user.Value.Id, matchGuid, beforeId, clamped, ct);
            return Ok(result);
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { error = ex.Message });
        }
    }

    [HttpPost]
    [EnableRateLimiting("messages-user")]
    public async Task<ActionResult<MessageDto>> Send(
        Guid matchGuid,
        [FromBody] SendMessageRequest request,
        CancellationToken ct = default)
    {
        var user = await ResolveUserAsync(ct);
        if (user is null) return Unauthorized();

        try
        {
            var dto = await _chats.SendAsync(user.Value.Id, user.Value.Guid, matchGuid, request.Body, request.ClientMsgId, ct);
            // Lenient: null -> match gone (hard-deleted). Mobile interprets 204 as "chat ended".
            if (dto is null) return NoContent();
            return Ok(dto);
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { error = ex.Message });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new { error = ex.Message });
        }
    }
}
