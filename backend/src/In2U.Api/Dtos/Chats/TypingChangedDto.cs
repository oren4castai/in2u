namespace In2U.Api.Dtos.Chats;

public sealed record TypingChangedDto(
    Guid MatchGuid,
    Guid FromUserGuid,
    bool IsTyping);
