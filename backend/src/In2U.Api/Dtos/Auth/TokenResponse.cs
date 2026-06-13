namespace In2U.Api.Dtos.Auth;

public sealed record TokenResponse
{
    public required string AccessToken { get; init; }
    public required string RefreshToken { get; init; }
    public required DateTime AccessExpiresAt { get; init; }
    public required UserDto User { get; init; }
    public bool Resumed { get; init; }
}
