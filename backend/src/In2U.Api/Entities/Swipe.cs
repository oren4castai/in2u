namespace In2U.Api.Entities;

public class Swipe
{
    public long Id { get; set; }
    public long FromUserId { get; set; }
    public long ToUserId { get; set; }
    public long VenueId { get; set; }
    public SwipeDirection Direction { get; set; }
    public TargetKind TargetKind { get; set; } = TargetKind.RealUser;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
