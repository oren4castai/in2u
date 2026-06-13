namespace In2U.Api.Dtos.Chats;

public sealed record MessageHistoryResponse(
    IReadOnlyList<MessageDto> Items,
    long? NextBeforeId);
