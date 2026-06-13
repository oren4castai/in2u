namespace In2U.Api.Entities;

public class AmbientSwipe
{
    public long Id { get; set; }
    public long FromUserId { get; set; }
    public long AmbientProfileId { get; set; }
    public long VenueId { get; set; }
    public SwipeDirection Direction { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
