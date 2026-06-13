using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Chats;
using In2U.Api.Entities;
using In2U.Api.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Services;

public sealed class ChatService : IChatService
{
    private const int MaxBodyLength = 2000;
    private const int MaxPageSize = 100;
    private const int PushBodyLength = 120;

    private readonly AppDbContext _db;
    private readonly IHubContext<VenueHub> _hub;
    private readonly IPushService _push;
    private readonly IGeoMembershipTracker _tracker;
    private readonly ILogger<ChatService> _log;

    public ChatService(
        AppDbContext db,
        IHubContext<VenueHub> hub,
        IPushService push,
        IGeoMembershipTracker tracker,
        ILogger<ChatService> log)
    {
        _db = db;
        _hub = hub;
        _push = push;
        _tracker = tracker;
        _log = log;
    }

    public async Task<MessageHistoryResponse> GetHistoryAsync(
        long requesterUserId, Guid matchGuid, long? beforeId, int limit = 50, CancellationToken ct = default)
    {
        var match = await _db.Matches.FirstOrDefaultAsync(m => m.MatchGuid == matchGuid, ct);
        // Lenient: match gone (hard-deleted) -> return empty history rather than throwing.
        if (match is null || match.EndedAt is not null)
            return new MessageHistoryResponse(Array.Empty<MessageDto>(), null);
        if (match.UserAId != requesterUserId && match.UserBId != requesterUserId)
            throw new UnauthorizedAccessException("Not a participant.");

        var take = Math.Clamp(limit, 1, MaxPageSize);

        var query = _db.ChatMessages.Where(m => m.MatchId == match.Id);
        if (beforeId is not null)
            query = query.Where(m => m.Id < beforeId.Value);

        var rows = await query
            .OrderByDescending(m => m.Id)
            .Take(take)
            .ToListAsync(ct);

        var userLookup = await _db.Users
            .Where(u => u.Id == match.UserAId || u.Id == match.UserBId)
            .Select(u => new { u.Id, u.UserGuid, u.DisplayName })
            .ToDictionaryAsync(u => u.Id, u => new { u.UserGuid, u.DisplayName }, ct);

        var items = rows.Select(m => new MessageDto(
            m.MessageGuid,
            match.MatchGuid,
            userLookup.TryGetValue(m.FromUserId, out var u) ? u.UserGuid : Guid.Empty,
            userLookup.TryGetValue(m.FromUserId, out var u2) ? (u2.DisplayName ?? string.Empty) : string.Empty,
            m.Body,
            m.SentAt,
            m.ReadAt,
            m.ClientMsgId)).ToList();

        long? nextBeforeId = rows.Count == take ? rows[^1].Id : null;

        return new MessageHistoryResponse(items, nextBeforeId);
    }

    public async Task<MessageDto?> SendAsync(
        long fromUserId, Guid fromUserGuid, Guid matchGuid, string body, string? clientMsgId, CancellationToken ct = default)
    {
        var trimmed = (body ?? string.Empty).Trim();
        if (trimmed.Length < 1 || trimmed.Length > MaxBodyLength)
            throw new ArgumentException($"Body must be 1-{MaxBodyLength} characters.");

        var match = await _db.Matches.FirstOrDefaultAsync(m => m.MatchGuid == matchGuid, ct);
        // Lenient: match gone (hard-deleted) -> silent success (caller returns 204).
        if (match is null || match.EndedAt is not null) return null;
        if (match.UserAId != fromUserId && match.UserBId != fromUserId)
            throw new UnauthorizedAccessException("Not a participant.");

        ChatMessage? entity = null;

        if (!string.IsNullOrEmpty(clientMsgId))
        {
            entity = await _db.ChatMessages
                .FirstOrDefaultAsync(m => m.MatchId == match.Id && m.ClientMsgId == clientMsgId, ct);
        }

        if (entity is null)
        {
            entity = new ChatMessage
            {
                MatchId = match.Id,
                FromUserId = fromUserId,
                Body = trimmed,
                SentAt = DateTime.UtcNow,
                ClientMsgId = string.IsNullOrEmpty(clientMsgId) ? null : clientMsgId,
            };
            _db.ChatMessages.Add(entity);
            try
            {
                await _db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                _db.Entry(entity).State = EntityState.Detached;
                var existing = await _db.ChatMessages
                    .FirstOrDefaultAsync(m => m.MatchId == match.Id && m.ClientMsgId == clientMsgId, ct);
                if (existing is null) throw;
                entity = existing;
            }
        }

        var participantGuids = await _db.Users
            .Where(u => u.Id == match.UserAId || u.Id == match.UserBId)
            .Select(u => new { u.Id, u.UserGuid, u.DisplayName })
            .ToListAsync(ct);

        var sender = participantGuids.FirstOrDefault(p => p.Id == entity.FromUserId);
        var fromGuid = sender?.UserGuid ?? fromUserGuid;
        var fromName = sender?.DisplayName ?? string.Empty;

        var dto = new MessageDto(
            entity.MessageGuid,
            match.MatchGuid,
            fromGuid,
            fromName,
            entity.Body,
            entity.SentAt,
            entity.ReadAt,
            entity.ClientMsgId);

        var recipientUserNames = participantGuids.Select(p => p.UserGuid.ToString()).ToList();
        await _hub.Clients.Users(recipientUserNames).SendAsync("MessageReceived", dto, ct);

        var recipient = participantGuids.FirstOrDefault(p => p.Id != fromUserId);
        if (recipient is not null && _tracker.ShouldPush(recipient.UserGuid))
        {
            var senderName = await _db.Users
                .Where(u => u.Id == fromUserId)
                .Select(u => u.DisplayName)
                .FirstOrDefaultAsync(ct) ?? "New message";

            var preview = trimmed.Length > PushBodyLength
                ? trimmed.Substring(0, PushBodyLength) + "\u2026"
                : trimmed;

            var data = new Dictionary<string, string>
            {
                ["type"] = "message",
                ["matchGuid"] = match.MatchGuid.ToString(),
                ["fromUserGuid"] = fromGuid.ToString(),
                ["messageGuid"] = entity.MessageGuid.ToString(),
            };
            var notification = new PushNotification(senderName, preview, data);
            try
            {
                await _push.SendToUserGuidAsync(recipient.UserGuid, notification, ct);
            }
            catch (Exception ex)
            {
                _log.LogWarning(ex, "Push for message failed.");
            }
        }

        return dto;
    }

    public async Task MarkReadAsync(
        long readerUserId, Guid readerUserGuid, Guid matchGuid, Guid messageGuid, CancellationToken ct = default)
    {
        var match = await _db.Matches.FirstOrDefaultAsync(m => m.MatchGuid == matchGuid, ct);
        // Lenient: match gone -> silent no-op.
        if (match is null || match.EndedAt is not null) return;
        if (match.UserAId != readerUserId && match.UserBId != readerUserId)
            throw new UnauthorizedAccessException("Not a participant.");

        var message = await _db.ChatMessages.FirstOrDefaultAsync(m => m.MessageGuid == messageGuid, ct);
        if (message is null) return;
        if (message.MatchId != match.Id) return;
        if (message.FromUserId == readerUserId) return;

        if (message.ReadAt is not null) return;

        message.ReadAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        var participantGuids = await _db.Users
            .Where(u => u.Id == match.UserAId || u.Id == match.UserBId)
            .Select(u => u.UserGuid.ToString())
            .ToListAsync(ct);

        var payload = new MessageReadDto(match.MatchGuid, message.MessageGuid, message.ReadAt.Value);
        await _hub.Clients.Users(participantGuids).SendAsync("MessageRead", payload, ct);
    }

    public async Task BroadcastTypingAsync(
        long fromUserId, Guid fromUserGuid, Guid matchGuid, bool isTyping, CancellationToken ct = default)
    {
        var match = await _db.Matches
            .Where(m => m.MatchGuid == matchGuid)
            .Select(m => new { m.Id, m.UserAId, m.UserBId, m.EndedAt })
            .FirstOrDefaultAsync(ct);
        // Lenient: match gone -> silent no-op.
        if (match is null || match.EndedAt is not null) return;
        if (match.UserAId != fromUserId && match.UserBId != fromUserId)
            throw new UnauthorizedAccessException("Not a participant.");

        var otherUserId = match.UserAId == fromUserId ? match.UserBId : match.UserAId;
        var otherGuid = await _db.Users
            .Where(u => u.Id == otherUserId)
            .Select(u => u.UserGuid)
            .FirstOrDefaultAsync(ct);
        if (otherGuid == Guid.Empty) return;

        var payload = new TypingChangedDto(matchGuid, fromUserGuid, isTyping);
        await _hub.Clients.User(otherGuid.ToString()).SendAsync("TypingChanged", payload, ct);
    }

    public Task DeleteMessagesForMatchAsync(long matchId, CancellationToken ct = default) =>
        _db.ChatMessages.Where(m => m.MatchId == matchId).ExecuteDeleteAsync(ct);

    public async Task DeleteMessagesForMatchesAsync(IEnumerable<long> matchIds, CancellationToken ct = default)
    {
        var ids = matchIds as IReadOnlyList<long> ?? matchIds.ToList();
        if (ids.Count == 0) return;
        await _db.ChatMessages.Where(m => ids.Contains(m.MatchId)).ExecuteDeleteAsync(ct);
    }

    public Task DeleteMessagesForVenueAsync(long venueId, CancellationToken ct = default) =>
        _db.ChatMessages
            .Where(m => _db.Matches.Any(x => x.Id == m.MatchId && x.VenueId == venueId))
            .ExecuteDeleteAsync(ct);
}
