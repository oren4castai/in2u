namespace In2U.Api.Dtos.Venues;

public sealed record VenueStatsDto(
    int JoinedCount,
    int MatchesCount,
    long ViewsCount,
    string ShareCode,
    int[] JoinedSparkline,
    int[] MatchesSparkline,
    long[] ViewsSparkline
);
