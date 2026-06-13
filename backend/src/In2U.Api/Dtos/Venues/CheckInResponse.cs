namespace In2U.Api.Dtos.Venues;

public sealed record CheckInResponse(Guid MembershipGuid, Guid VenueGuid, DateTime CheckedInAt);
