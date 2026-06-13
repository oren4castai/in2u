using In2U.Api.Dtos.Swipes;
using In2U.Api.Entities;

namespace In2U.Api.Services;

public interface ISwipeService
{
    Task<SwipeResponse> RecordAsync(long fromUserId, Guid toUserGuid, Guid venueGuid, SwipeDirection direction, CancellationToken ct = default);
    Task<FeedResponse> GetFeedAsync(long userId, Guid venueGuid, string? cursor, int limit = 20, CancellationToken ct = default);
}
