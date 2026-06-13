using System.Text.RegularExpressions;
using Google.Apis.Auth;
using In2U.Api.Data;
using In2U.Api.Dtos.Auth;
using In2U.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Services;

public sealed class AuthService : IAuthService
{
    private static readonly Regex EmailRegex =
        new(@"^[^\s@]+@[^\s@]+\.[^\s@]+$", RegexOptions.Compiled | RegexOptions.IgnoreCase);

    private readonly AppDbContext _db;
    private readonly IJwtService _jwt;
    private readonly ISessionPurgeService _sessionPurge;
    private readonly IEventResumeService _eventResume;
    private readonly ILogger<AuthService> _log;

    public AuthService(
        AppDbContext db,
        IJwtService jwt,
        ISessionPurgeService sessionPurge,
        IEventResumeService eventResume,
        ILogger<AuthService> log)
    {
        _db = db;
        _jwt = jwt;
        _sessionPurge = sessionPurge;
        _eventResume = eventResume;
        _log = log;
    }

    public async Task<TokenResponse> RegisterEmailAsync(string email, string password, string displayName, CancellationToken ct = default)
    {
        email = (email ?? string.Empty).Trim().ToLowerInvariant();
        displayName = (displayName ?? string.Empty).Trim();

        if (!EmailRegex.IsMatch(email))
            throw new ArgumentException("Invalid email format.");
        if (string.IsNullOrWhiteSpace(password) || password.Length < 8)
            throw new ArgumentException("Password must be at least 8 characters.");
        if (string.IsNullOrWhiteSpace(displayName))
            throw new ArgumentException("DisplayName is required.");

        var exists = await _db.Users.AnyAsync(u => u.Email == email, ct);
        if (exists)
            throw new InvalidOperationException("Email is already registered.");

        var user = new User
        {
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            AuthProvider = AuthProvider.Email,
            DisplayName = displayName,
            CreatedAt = DateTime.UtcNow,
            LastSeenAt = DateTime.UtcNow,
            Role = UserRole.User,
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync(ct);

        return await IssueTokensAsync(user, resumed: false, ct);
    }

    public async Task<TokenResponse> LoginEmailAsync(string email, string password, CancellationToken ct = default)
    {
        email = (email ?? string.Empty).Trim().ToLowerInvariant();
        var user = await _db.Users.FirstOrDefaultAsync(
            u => u.Email == email && !u.IsDeleted && u.AuthProvider == AuthProvider.Email, ct);

        if (user is null || string.IsNullOrEmpty(user.PasswordHash) ||
            !BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
            throw new UnauthorizedAccessException("Invalid email or password.");

        var resumed = await PrepareSessionForLoginAsync(user.Id, "email", ct);

        return await IssueTokensAsync(user, resumed, ct);
    }

    public async Task<TokenResponse> LoginGoogleAsync(string idToken, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(idToken))
            throw new ArgumentException("idToken is required.");

        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await GoogleJsonWebSignature.ValidateAsync(idToken);
        }
        catch (InvalidJwtException ex)
        {
            throw new UnauthorizedAccessException("Invalid Google id token: " + ex.Message);
        }

        var sub = payload.Subject;
        var email = (payload.Email ?? string.Empty).Trim().ToLowerInvariant();
        var displayName = payload.Name ?? (email.Length > 0 ? email.Split('@')[0] : "user");

        var user = await _db.Users.FirstOrDefaultAsync(
            u => u.AuthProvider == AuthProvider.Google && u.ExternalId == sub, ct);

        if (user is null && !string.IsNullOrEmpty(email))
            user = await _db.Users.FirstOrDefaultAsync(u => u.Email == email, ct);

        if (user is null)
        {
            user = new User
            {
                Email = email,
                AuthProvider = AuthProvider.Google,
                ExternalId = sub,
                DisplayName = displayName,
                CreatedAt = DateTime.UtcNow,
                LastSeenAt = DateTime.UtcNow,
                Role = UserRole.User,
            };
            _db.Users.Add(user);
            await _db.SaveChangesAsync(ct);
        }
        else
        {
            if (user.IsDeleted)
                throw new UnauthorizedAccessException("Account is deleted.");

            if (user.AuthProvider != AuthProvider.Google)
            {
                user.AuthProvider = AuthProvider.Google;
                user.ExternalId = sub;
            }
            else if (string.IsNullOrEmpty(user.ExternalId))
            {
                user.ExternalId = sub;
            }

            var resumedExisting = await PrepareSessionForLoginAsync(user.Id, "google", ct);
            return await IssueTokensAsync(user, resumedExisting, ct);
        }

        return await IssueTokensAsync(user, resumed: false, ct);
    }

    public Task<TokenResponse> LoginAppleAsync(string identityToken, string? nonce, CancellationToken ct = default)
        => throw new NotImplementedException("Apple sign-in arrives in P5 polish");

    public async Task<TokenResponse> RefreshAsync(string refreshToken, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
            throw new UnauthorizedAccessException("Refresh token required.");

        var hash = _jwt.HashRefreshToken(refreshToken);
        var now = DateTime.UtcNow;
        var user = await _db.Users.FirstOrDefaultAsync(
            u => u.RefreshTokenHash == hash &&
                 u.RefreshTokenExpiresAt != null &&
                 u.RefreshTokenExpiresAt > now &&
                 !u.IsDeleted, ct);

        if (user is null)
            throw new UnauthorizedAccessException("Invalid or expired refresh token.");

        return await IssueTokensAsync(user, resumed: false, ct);
    }

    public async Task LogoutAsync(long userId, CancellationToken ct = default)
    {
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);
        if (user is null) return;

        user.RefreshTokenHash = null;
        user.RefreshTokenExpiresAt = null;

        await _db.SaveChangesAsync(ct);
    }

    private async Task<bool> PrepareSessionForLoginAsync(long userId, string provider, CancellationToken ct)
    {
        bool resumed;
        try
        {
            resumed = await _eventResume.IsEligibleAsync(userId, ct);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Resume eligibility check failed for user {UserId} on {Provider} login.", userId, provider);
            resumed = false;
        }

        if (resumed)
            return true;

        try
        {
            _log.LogInformation("Purging session data for user {UserId} on {Provider} login.", userId, provider);
            await _sessionPurge.PurgeSessionDataAsync(userId, ct);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Session purge failed for user {UserId} on {Provider} login; continuing login.", userId, provider);
        }

        return false;
    }

    private async Task<TokenResponse> IssueTokensAsync(User user, bool resumed, CancellationToken ct)
    {
        var access = _jwt.CreateAccessToken(user);
        var accessExpiry = _jwt.GetAccessTokenExpiry();
        var refreshPlain = _jwt.CreateRefreshTokenPlain();
        var refreshHash = _jwt.HashRefreshToken(refreshPlain);

        user.RefreshTokenHash = refreshHash;
        user.RefreshTokenExpiresAt = _jwt.GetRefreshTokenExpiry();
        user.LastSeenAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);

        return new TokenResponse
        {
            AccessToken = access,
            RefreshToken = refreshPlain,
            AccessExpiresAt = accessExpiry,
            User = MapUser(user),
            Resumed = resumed,
        };
    }

    public static UserDto MapUser(User u) => new()
    {
        UserGuid = u.UserGuid,
        Email = u.Email,
        DisplayName = u.DisplayName,
        Bio = u.Bio,
        PhotoUrl = u.HasPhoto ? $"/api/v1/photos/{u.UserGuid}" : null,
        BirthYear = u.BirthYear,
        Gender = u.Gender?.ToString(),
        PreferGender = u.PreferGender.ToString(),
        Role = u.Role.ToString(),
    };
}
