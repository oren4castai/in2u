using In2U.Api.Dtos.Chats;

namespace In2U.Api.Services;

public interface IChatService
{
    Task<MessageHistoryResponse> GetHistoryAsync(
        long requesterUserId, Guid matchGuid, long? beforeId, int limit = 50, CancellationToken ct = default);

    Task<MessageDto?> SendAsync(
        long fromUserId, Guid fromUserGuid, Guid matchGuid, string body, string? clientMsgId, CancellationToken ct = default);

    Task MarkReadAsync(
        long readerUserId, Guid readerUserGuid, Guid matchGuid, Guid messageGuid, CancellationToken ct = default);

    Task BroadcastTypingAsync(
        long fromUserId, Guid fromUserGuid, Guid matchGuid, bool isTyping, CancellationToken ct = default);

    Task DeleteMessagesForMatchAsync(long matchId, CancellationToken ct = default);

    Task DeleteMessagesForMatchesAsync(IEnumerable<long> matchIds, CancellationToken ct = default);

    Task DeleteMessagesForVenueAsync(long venueId, CancellationToken ct = default);
}
