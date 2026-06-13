using In2U.Api.Data;
using In2U.Api.Entities;
using In2U.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Hubs;

[Authorize]
public sealed class VenueHub : Hub
{
    private readonly AppDbContext _db;
    private readonly IGeoMembershipTracker _tracker;
    private readonly ILocationValidationService _locationValidation;
    private readonly IChatService _chats;

    public VenueHub(
        AppDbContext db,
        IGeoMembershipTracker tracker,
        ILocationValidationService locationValidation,
        IChatService chats)
    {
        _db = db;
        _tracker = tracker;
        _locationValidation = locationValidation;
        _chats = chats;
    }

    private Guid? GetUserGuid()
    {
        var raw = Context.User?.FindFirst("sub")?.Value
                  ?? Context.User?.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub)?.Value;
        return Guid.TryParse(raw, out var g) ? g : null;
    }

    private async Task<(long UserId, Guid UserGuid)?> ResolveUserAsync()
    {
        var guid = GetUserGuid();
        if (guid is null) return null;
        var id = await _db.Users
            .Where(u => u.UserGuid == guid.Value && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(Context.ConnectionAborted);
        if (id is null) return null;
        return (id.Value, guid.Value);
    }

    public override async Task OnConnectedAsync()
    {
        var user = await ResolveUserAsync();
        if (user is null)
        {
            Context.Abort();
            return;
        }

        _tracker.AddConnection(user.Value.UserGuid, Context.ConnectionId);
        // Default to foreground when a client connects without explicitly reporting app state.
        _tracker.SetAppState(user.Value.UserGuid, true);

        var active = await _db.VenueMemberships
            .Where(m => m.UserId == user.Value.UserId)
            .Join(_db.Venues, m => m.VenueId, v => v.Id, (m, v) => new { m.MembershipGuid, v.VenueGuid })
            .FirstOrDefaultAsync(Context.ConnectionAborted);

        if (active is not null)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"venue_{active.VenueGuid}", Context.ConnectionAborted);
            await Clients.Caller.SendAsync(
                "VenueJoined",
                new { venueGuid = active.VenueGuid, membershipGuid = active.MembershipGuid },
                Context.ConnectionAborted);
        }

        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var guid = GetUserGuid();
        if (guid is not null)
        {
            _tracker.RemoveConnection(guid.Value, Context.ConnectionId);
            if (!_tracker.IsConnected(guid.Value))
                await StampLastActiveForEventMembershipAsync(guid.Value, CancellationToken.None);
        }
        await base.OnDisconnectedAsync(exception);
    }

    public async Task JoinVenue(Guid venueGuid)
    {
        var user = await ResolveUserAsync()
                   ?? throw new HubException("Unauthorized.");

        var hasActive = await _db.VenueMemberships
            .Where(m => m.UserId == user.UserId)
            .Join(_db.Venues, m => m.VenueId, v => v.Id, (m, v) => v.VenueGuid)
            .AnyAsync(g => g == venueGuid, Context.ConnectionAborted);

        if (!hasActive)
            throw new HubException("No active membership for this venue.");

        await Groups.AddToGroupAsync(Context.ConnectionId, $"venue_{venueGuid}", Context.ConnectionAborted);
    }

    public Task LeaveVenue(Guid venueGuid) =>
        Groups.RemoveFromGroupAsync(Context.ConnectionId, $"venue_{venueGuid}", Context.ConnectionAborted);

    public async Task SendLocation(Guid venueGuid, double lat, double lng)
    {
        var user = await ResolveUserAsync()
                   ?? throw new HubException("Unauthorized.");
        try
        {
            await _locationValidation.UpdateAsync(user.UserId, venueGuid, lat, lng, Context.ConnectionAborted);
        }
        catch (InvalidOperationException ex)
        {
            throw new HubException(ex.Message);
        }
    }

    public async Task SendMessage(Guid matchGuid, string body, string? clientMsgId)
    {
        var user = await ResolveUserAsync()
                   ?? throw new HubException("Unauthorized.");
        try
        {
            await _chats.SendAsync(user.UserId, user.UserGuid, matchGuid, body, clientMsgId, Context.ConnectionAborted);
        }
        catch (ArgumentException ex)
        {
            throw new HubException(ex.Message);
        }
        catch (UnauthorizedAccessException)
        {
            // Lenient: match gone or not a participant -> silent no-op.
        }
    }

    public async Task Typing(Guid matchGuid, bool isTyping)
    {
        var user = await ResolveUserAsync()
                   ?? throw new HubException("Unauthorized.");
        try
        {
            await _chats.BroadcastTypingAsync(user.UserId, user.UserGuid, matchGuid, isTyping, Context.ConnectionAborted);
        }
        catch (UnauthorizedAccessException)
        {
            // Lenient: match gone -> silent no-op.
        }
    }

    public async Task MarkRead(Guid matchGuid, Guid messageGuid)
    {
        var user = await ResolveUserAsync()
                   ?? throw new HubException("Unauthorized.");
        try
        {
            await _chats.MarkReadAsync(user.UserId, user.UserGuid, matchGuid, messageGuid, Context.ConnectionAborted);
        }
        catch (UnauthorizedAccessException)
        {
            // Lenient: match gone -> silent no-op.
        }
    }

    public async Task SetAppState(bool isForeground)
    {
        var guid = GetUserGuid();
        if (guid is null) throw new HubException("Unauthorized.");
        _tracker.SetAppState(guid.Value, isForeground);
        if (!isForeground)
            await StampLastActiveForEventMembershipAsync(guid.Value, Context.ConnectionAborted);
    }

    private async Task StampLastActiveForEventMembershipAsync(Guid userGuid, CancellationToken ct)
    {
        var userId = await _db.Users
            .Where(u => u.UserGuid == userGuid && !u.IsDeleted)
            .Select(u => (long?)u.Id)
            .FirstOrDefaultAsync(ct);
        if (userId is null)
            return;

        var membership = await _db.VenueMemberships
            .Where(m => m.UserId == userId.Value)
            .Join(_db.Venues, m => m.VenueId, v => v.Id, (m, v) => new { m, v })
            .Where(x => x.v.Type == VenueType.Event)
            .Select(x => x.m)
            .FirstOrDefaultAsync(ct);

        if (membership is null)
            return;

        membership.LastActiveAtUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
    }
}
