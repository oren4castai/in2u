namespace In2U.Api.Entities;

public class AmbientProfile
{
    public long Id { get; set; }
    public Guid AmbientProfileGuid { get; set; } = Guid.NewGuid();
    public string DisplayName { get; set; } = string.Empty;
    public string PictureUrl { get; set; } = string.Empty;
    public string? Gender { get; set; }
    public List<string> StyleTags { get; set; } = new();
    public string? AgeRange { get; set; }
    public AmbientBlurLevel BlurLevel { get; set; } = AmbientBlurLevel.Low;
    public bool Active { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
