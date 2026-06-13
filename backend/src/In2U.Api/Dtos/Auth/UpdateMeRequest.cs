namespace In2U.Api.Dtos.Auth;

public sealed record UpdateMeRequest
{
    public string? DisplayName { get; init; }
    public string? Bio { get; init; }
    public int? BirthYear { get; init; }
    public string? Gender { get; init; }
    public string? PreferGender { get; init; }
}
