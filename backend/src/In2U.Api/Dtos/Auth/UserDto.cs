namespace In2U.Api.Dtos.Auth;

public sealed record UserDto
{
    public required Guid UserGuid { get; init; }
    public required string Email { get; init; }
    public required string DisplayName { get; init; }
    public string? Bio { get; init; }
    public string? PhotoUrl { get; init; }
    public int? BirthYear { get; init; }
    public string? Gender { get; init; }
    public required string PreferGender { get; init; }
    public required string Role { get; init; }
}
