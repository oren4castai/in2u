using In2U.Api.Dtos.Auth;

namespace In2U.Api.Services;

public interface IAuthService
{
    Task<TokenResponse> RegisterEmailAsync(string email, string password, string displayName, CancellationToken ct = default);
    Task<TokenResponse> LoginEmailAsync(string email, string password, CancellationToken ct = default);
    Task<TokenResponse> LoginGoogleAsync(string idToken, CancellationToken ct = default);
    Task<TokenResponse> LoginAppleAsync(string identityToken, string? nonce, CancellationToken ct = default);
    Task<TokenResponse> RefreshAsync(string refreshToken, CancellationToken ct = default);
    Task LogoutAsync(long userId, CancellationToken ct = default);
}
