namespace In2U.Api.Dtos.Swipes;

public sealed record FeedResponse(IReadOnlyList<FeedItemDto> Items, string? NextCursor);
