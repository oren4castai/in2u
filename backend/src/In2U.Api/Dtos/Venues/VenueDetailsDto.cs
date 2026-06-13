using In2U.Api.Dtos.Ambient;

namespace In2U.Api.Dtos.Venues;

public sealed record VenueDetailsDto(
    Guid VenueGuid,
    string Name,
    string? Description,
    string Type,
    string EventType,
    double Lat,
    double Lng,
    int RadiusM,
    double DistanceM,
    string DensityBucket,
    DateTime? StartsAt,
    int? DurationHours,
    string Status,
    bool HasPhoto,
    IReadOnlyList<string> PreviewAvatars,
    IReadOnlyList<AmbientPreviewDto> AmbientPreview,
    string? Category
);
