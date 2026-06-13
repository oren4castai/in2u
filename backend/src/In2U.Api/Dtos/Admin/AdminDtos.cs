namespace In2U.Api.Dtos.Admin;

public sealed record AdminStatsDto(
    int UsersTotal,
    int UsersOnline,
    int VenuesTotal,
    int EventsTotal,
    int EventsActive,
    int PublicEventsTotal,
    int PrivateEventsTotal,
    int PublicEventsActive,
    int PrivateEventsActive);

public sealed record AdminUserDto(
    Guid UserGuid,
    string DisplayName,
    string Email,
    string Role,
    bool IsVenueOwner,
    bool HasActiveEvent,
    bool HasPhoto,
    DateTime LastSeenAt);

public sealed record AdminVenueDto(
    Guid VenueGuid,
    string Name,
    string Type,
    string Status,
    string EventType,
    bool HasPhoto,
    string? CreatorName,
    string? OwnerName,
    DateTime CreatedAt);

public sealed record AdminEventDto(
    Guid VenueGuid,
    string Name,
    string Status,
    string EventType,
    bool IsPaused,
    bool HasPhoto,
    string? CreatorName,
    string? OwnerName,
    DateTime? StartsAt,
    DateTime CreatedAt);

public sealed record AdminVenueClaimDto(
    Guid ClaimGuid,
    string Name,
    string ContactName,
    string ContactPhone,
    double Lat,
    double Lng,
    int RadiusM,
    string Status,
    string? AdminNote,
    DateTime CreatedAt);