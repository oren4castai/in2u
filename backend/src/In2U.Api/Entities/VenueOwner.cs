namespace In2U.Api.Entities;

public class VenueOwner
{
    public long Id { get; set; }
    public Guid VenueOwnerGuid { get; set; } = Guid.NewGuid();
    public long CreateUserId { get; set; }
    public double Lat { get; set; }
    public double Lng { get; set; }
    public int RadiusM { get; set; }
    public string Name { get; set; } = string.Empty;
    public int AllowPublicEventsCount { get; set; }
    public bool HasPhoto { get; set; }
}
