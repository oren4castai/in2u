namespace In2U.Api.Dtos.Matches;

public sealed record MatchDto(
    Guid MatchGuid,
    Guid VenueGuid,
    string VenueName,
    DateTime CreatedAt,
    MatchPeerDto Peer);
