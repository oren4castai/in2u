namespace In2U.Api.Dtos.Venues;

public sealed record PatchEventRequest(
    string? Name,
    string? Description,
    int? DurationHours
);
