namespace In2U.Api.Entities;

public class VenueOwnerEventLog
{
    public long Id { get; set; }
    public long VenueOwnerId { get; set; }
    public long VenueId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateTime? StartsAt { get; set; }
    public int? DurationHours { get; set; }
    public string EventType { get; set; } = string.Empty;
    public int JoinedCount { get; set; }
    public int MatchesCount { get; set; }
    public long ViewsCount { get; set; }
    public string CreateUserName { get; set; } = string.Empty;
    public DateTime ClosedAt { get; set; } = DateTime.UtcNow;
}
