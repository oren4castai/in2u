namespace In2U.Api.Dtos.Venues;

public sealed record CreateVenueRequest(
    string Name,
    string? Description,
    string Type,
    string? EventType,
    double Lat,
    double Lng,
    int RadiusM,
    DateTime? StartsAt,
    int? DurationHours,
    long? OwnerId,
    string? Category
);
