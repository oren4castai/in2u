namespace In2U.Api.Dtos.Venues;

public sealed record MyEventDto(
    Guid VenueGuid,
    string Name,
    string? Description,
    string EventType,
    double Lat,
    double Lng,
    int RadiusM,
    DateTime? StartsAt,
    int? DurationHours,
    string Status,
    bool HasPhoto,
    string ShareCode
);
