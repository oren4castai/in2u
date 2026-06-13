namespace In2U.Api.Dtos.Venues;

public sealed record CreateEventRequest(
    string Name,
    string? Description,
    string EventType,
    double Lat,
    double Lng,
    int RadiusM,
    DateTime StartsAt,
    int DurationHours,
    string? Category
);
