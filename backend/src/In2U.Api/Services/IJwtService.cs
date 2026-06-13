using In2U.Api.Entities;

namespace In2U.Api.Services;

public interface IJwtService
{
    string CreateAccessToken(User user);
    string CreateRefreshTokenPlain();
    string HashRefreshToken(string plain);
    DateTime GetAccessTokenExpiry();
    DateTime GetRefreshTokenExpiry();
}
