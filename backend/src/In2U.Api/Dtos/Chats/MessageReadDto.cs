namespace In2U.Api.Dtos.Chats;

public sealed record MessageReadDto(
    Guid MatchGuid,
    Guid MessageGuid,
    DateTime ReadAt);
