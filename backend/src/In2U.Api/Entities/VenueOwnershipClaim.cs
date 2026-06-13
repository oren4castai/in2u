namespace In2U.Api.Entities;

public class VenueOwnershipClaim
{
    public long Id { get; set; }
    public Guid ClaimGuid { get; set; } = Guid.NewGuid();
    public long RequestUserId { get; set; }
    public double Lat { get; set; }
    public double Lng { get; set; }
    public int RadiusM { get; set; }
    public string Name { get; set; } = string.Empty;
    public string ContactName { get; set; } = string.Empty;
    public string ContactPhone { get; set; } = string.Empty;
    public byte[] PhotoData { get; set; } = Array.Empty<byte>();
    public string PhotoContentType { get; set; } = "image/jpeg";
    public ClaimStatus Status { get; set; } = ClaimStatus.Pending;
    public string? AdminNote { get; set; }
    public long? CreatedVenueOwnerId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
