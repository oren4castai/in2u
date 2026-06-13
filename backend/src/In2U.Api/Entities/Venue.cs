namespace In2U.Api.Entities;

public class Venue
{
    public long Id { get; set; }
    public Guid VenueGuid { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public VenueType Type { get; set; }
    public VenueEventType EventType { get; set; } = VenueEventType.Public;
    public double Lat { get; set; }
    public double Lng { get; set; }
    public int RadiusM { get; set; }
    public DateTime? StartsAt { get; set; }
    public int? DurationHours { get; set; }
    public VenueStatus Status { get; set; } = VenueStatus.Active;
    public EventCategory? Category { get; set; }
    public long CreateUserId { get; set; }
    public long? OwnerId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool HasPhoto { get; set; }
    public bool IsPaused { get; set; }
    public string ShareCode { get; set; } = string.Empty;
}
