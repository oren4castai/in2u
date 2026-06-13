using In2U.Api.Dtos.Matches;
using In2U.Api.Entities;

namespace In2U.Api.Services;

public interface IMatchService
{
    Task<MatchDto?> CreateIfMutualRightAsync(long fromUserId, long toUserId, long venueId, CancellationToken ct = default);
    Task<IReadOnlyList<MatchDto>> ListActiveForUserAsync(long userId, CancellationToken ct = default);
    Task<bool> EndMatchAsync(Guid matchGuid, long requesterUserId, MatchEndReason reason, CancellationToken ct = default);
    Task EndMembershipMatchesAsync(long userId, long venueId, MatchEndReason reason, CancellationToken ct = default);
    Task EndVenueMatchesAsync(long venueId, MatchEndReason reason, CancellationToken ct = default);
    Task EndMatchesBetweenAsync(long userAId, long userBId, MatchEndReason reason, CancellationToken ct = default);
    Task EndAllUserMatchesAsync(long userId, MatchEndReason reason, CancellationToken ct = default);
}
