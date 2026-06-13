namespace In2U.Api.Entities;

public class VenueStats
{
    public long VenueId { get; set; }
    public int JoinedCount { get; set; }
    public int MatchesCount { get; set; }
    public long ViewsCount { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
