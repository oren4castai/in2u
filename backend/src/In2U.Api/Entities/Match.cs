namespace In2U.Api.Entities;

public class Match
{
    public long Id { get; set; }
    public Guid MatchGuid { get; set; } = Guid.NewGuid();
    public long VenueId { get; set; }
    public long UserAId { get; set; }
    public long UserBId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? EndedAt { get; set; }
    public MatchEndReason? EndReason { get; set; }
}
