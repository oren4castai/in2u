namespace In2U.Api.Dtos.Chats;

public sealed record SendMessageRequest(string Body, string? ClientMsgId);
