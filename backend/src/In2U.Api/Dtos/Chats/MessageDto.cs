namespace In2U.Api.Dtos.Chats;

public sealed record MessageDto(
    Guid MessageGuid,
    Guid MatchGuid,
    Guid FromUserGuid,
    string FromDisplayName,
    string Body,
    DateTime SentAt,
    DateTime? ReadAt,
    string? ClientMsgId);
