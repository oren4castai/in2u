using In2U.Api.Entities;

namespace In2U.Api.Dtos.Ambient;

public sealed record AmbientPreviewDto(
    Guid AmbientProfileGuid,
    string PictureUrl,
    AmbientBlurLevel BlurLevel,
    string DisplayName);

public sealed record AmbientFeedItem(
    Guid AmbientProfileGuid,
    string DisplayName,
    string PictureUrl,
    AmbientBlurLevel BlurLevel,
    string? AgeRange,
    List<string> StyleTags);

public sealed record AmbientProfileSeed(
    string DisplayName,
    string PictureUrl,
    string? Gender,
    List<string>? StyleTags,
    string? AgeRange,
    AmbientBlurLevel BlurLevel);

public sealed record AmbientReplaceRequest(List<AmbientProfileSeed> Profiles);
