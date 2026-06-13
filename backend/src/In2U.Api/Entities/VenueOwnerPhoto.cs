namespace In2U.Api.Entities;

public class VenueOwnerPhoto
{
    public long Id { get; set; }
    public long VenueOwnerId { get; set; }
    public byte[] Data { get; set; } = Array.Empty<byte>();
    public string ContentType { get; set; } = "image/jpeg";
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
