namespace In2U.Api.Entities;

public class User
{
    public long Id { get; set; }
    public Guid UserGuid { get; set; } = Guid.NewGuid();
    public string Email { get; set; } = string.Empty;
    public string? PasswordHash { get; set; }
    public AuthProvider AuthProvider { get; set; }
    public string? ExternalId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string? Bio { get; set; }
    public bool HasPhoto { get; set; }
    public int? BirthYear { get; set; }
    public Gender? Gender { get; set; }
    public GenderPreference PreferGender { get; set; } = GenderPreference.Everyone;
    public DateTime CreatedAt { get; set; }
    public DateTime LastSeenAt { get; set; }
    public bool IsDeleted { get; set; }
    public UserRole Role { get; set; } = UserRole.User;
    public string? RefreshTokenHash { get; set; }
    public DateTime? RefreshTokenExpiresAt { get; set; }
}
