namespace In2U.Api.Dtos.Auth;

public sealed record LoginRequest
{
    public required string Email { get; init; }
    public required string Password { get; init; }
}
