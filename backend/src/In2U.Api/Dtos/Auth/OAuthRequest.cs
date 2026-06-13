namespace In2U.Api.Dtos.Auth;

public sealed record OAuthRequest
{
    public required string IdToken { get; init; }
    public string? Nonce { get; init; }
}
