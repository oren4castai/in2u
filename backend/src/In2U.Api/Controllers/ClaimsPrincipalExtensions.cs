using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace In2U.Api.Controllers;

public static class ClaimsPrincipalExtensions
{
    public static Guid? GetUserGuid(this ClaimsPrincipal principal)
    {
        var raw = principal.FindFirstValue(JwtRegisteredClaimNames.Sub)
                  ?? principal.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(raw, out var g) ? g : null;
    }
}
