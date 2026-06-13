namespace In2U.Api.Dtos.Matches;

public sealed record MatchPeerDto(
    Guid UserGuid,
    string DisplayName,
    string? Bio,
    string? PhotoUrl,
    int? BirthYear,
    string? Gender);
