using In2U.Api.Entities;

namespace In2U.Api.Dtos.Swipes;

public sealed record FeedItemDto(
    Guid UserGuid,
    string DisplayName,
    string? Bio,
    string? PhotoUrl,
    int? BirthYear,
    string? Gender,
    string Kind = "user",
    AmbientBlurLevel? Blur = null,
    List<string>? StyleTags = null);
