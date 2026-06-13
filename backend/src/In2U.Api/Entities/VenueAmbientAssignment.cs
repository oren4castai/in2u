namespace In2U.Api.Entities;

public class VenueAmbientAssignment
{
    public long Id { get; set; }
    public Guid AssignmentGuid { get; set; } = Guid.NewGuid();
    public long VenueId { get; set; }
    public Venue Venue { get; set; } = null!;
    public long AmbientProfileId { get; set; }
    public AmbientProfile AmbientProfile { get; set; } = null!;
    public DateTime AssignedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; }
    public bool Active { get; set; } = true;
}
