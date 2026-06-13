namespace In2U.Api.Dtos.Owners;

public sealed record SubmitClaimResponse(Guid ClaimGuid);

public sealed record GovernancePreviewDto(
    bool Governed,
    string? OwnerName,
    bool PrivateAllowed,
    int? PublicSlotsRemaining);

public sealed record ClaimConflictDto(Guid OwnerGuid, string OwnerName, double DistanceMeters, string Type);

public sealed record PendingClaimDto(
    Guid ClaimGuid,
    string Name,
    string ContactName,
    string ContactPhone,
    double Lat,
    double Lng,
    int RadiusM,
    DateTime CreatedAt,
    IReadOnlyList<ClaimConflictDto> Conflicts);

public sealed record RejectClaimRequest(string? Note);

public sealed record OwnerPastEventDto(
    long Id,
    string Name,
    DateTime ClosedAt,
    int JoinedCount,
    int MatchesCount,
    long ViewsCount);

public sealed record OwnerVenueSummaryDto(
    Guid OwnerGuid,
    string Name,
    int ActiveEventCount,
    int LiveCount,
    bool HasPhoto);

public sealed record OwnerAccumulatedTotalsDto(
    int Joined,
    int Matches,
    long Views);

public sealed record OwnerActiveEventDto(
    Guid VenueGuid,
    string Name,
    string Status,
    bool IsPaused,
    bool IsMine,
    DateTime? StartsAt,
    int? DurationHours,
    int LiveCount,
    int JoinedCount,
    int MatchesCount,
    long ViewsCount);

public sealed record OwnerVenueDetailDto(
    Guid OwnerGuid,
    string Name,
    double Lat,
    double Lng,
    int RadiusM,
    int AllowPublicEventsCount,
    bool HasPhoto,
    OwnerAccumulatedTotalsDto Totals,
    IReadOnlyList<OwnerActiveEventDto> ActiveEvents,
    IReadOnlyList<OwnerPastEventDto> PastEvents);

public sealed record SendVenueAnnouncementRequest(string Message);

public sealed record MyClaimDto(
    Guid ClaimGuid,
    string Name,
    double Lat,
    double Lng,
    int RadiusM,
    string Status,
    string? AdminNote,
    DateTime CreatedAt);

