namespace In2U.Api.Dtos.Venues;

public sealed record VenueParticipantDto(
    Guid UserGuid,
    string DisplayName,
    bool HasPhoto,
    int? BirthYear,
    DateTime CheckedInAt
);
