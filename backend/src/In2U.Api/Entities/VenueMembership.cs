namespace In2U.Api.Entities;

public class VenueMembership
{
    public long Id { get; set; }
    public Guid MembershipGuid { get; set; } = Guid.NewGuid();
    public long UserId { get; set; }
    public long VenueId { get; set; }
    public DateTime CheckedInAt { get; set; }
    public DateTime? LastActiveAtUtc { get; set; }
    public DateTime LastLocationAt { get; set; }
    public double LastLat { get; set; }
    public double LastLng { get; set; }
}
