namespace In2U.Api.Dtos.Auth;

public sealed record RefreshRequest
{
    public required string RefreshToken { get; init; }
}
