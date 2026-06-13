using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.SignalR;

namespace In2U.Api.Hubs;

public sealed class UserGuidProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection)
    {
        return connection.User?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value
            ?? connection.User?.FindFirst("sub")?.Value;
    }
}
