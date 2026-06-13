using In2U.Api.Data;
using In2U.Api.Dtos.Admin;
using In2U.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Services;

public sealed class AdminModerationService : IAdminModerationService
{
    private readonly AppDbContext _db;
    private readonly IGeoMembershipTracker _tracker;

    public AdminModerationService(AppDbContext db, IGeoMembershipTracker tracker)
    {
        _db = db;
        _tracker = tracker;
    }

    public async Task<AdminStatsDto> GetStatsAsync(CancellationToken ct = default)
    {
        var usersTotal = await _db.Users.CountAsync(u => !u.IsDeleted, ct);
        var venuesTotal = await _db.Venues.CountAsync(v => v.Type == VenueType.Global, ct);
        var eventsTotal = await _db.Venues.CountAsync(v => v.Type == VenueType.Event, ct);
        var eventsActive = await _db.Venues.CountAsync(v => v.Type == VenueType.Event && v.Status == VenueStatus.Active, ct);
        var publicEventsTotal = await _db.Venues.CountAsync(v => v.Type == VenueType.Event && v.EventType == VenueEventType.Public, ct);
        var privateEventsTotal = await _db.Venues.CountAsync(v => v.Type == VenueType.Event && v.EventType == VenueEventType.Private, ct);
        var publicEventsActive = await _db.Venues.CountAsync(v => v.Type == VenueType.Event && v.Status == VenueStatus.Active && v.EventType == VenueEventType.Public, ct);
        var privateEventsActive = await _db.Venues.CountAsync(v => v.Type == VenueType.Event && v.Status == VenueStatus.Active && v.EventType == VenueEventType.Private, ct);

        return new AdminStatsDto(
            usersTotal,
            _tracker.GetConnectedUserCount(),
            venuesTotal,
            eventsTotal,
            eventsActive,
            publicEventsTotal,
            privateEventsTotal,
            publicEventsActive,
            privateEventsActive);
    }

    public async Task<IReadOnlyList<AdminUserDto>> ListUsersAsync(string? search, CancellationToken ct = default)
    {
        var q = _db.Users
            .Where(u => !u.IsDeleted)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            q = q.Where(u =>
                u.DisplayName.ToLower().Contains(s) ||
                u.Email.ToLower().Contains(s) ||
                u.UserGuid.ToString().ToLower().Contains(s));
        }

        var rows = await q
            .OrderByDescending(u => u.LastSeenAt)
            .Take(200)
            .Select(u => new
            {
                u.Id,
                u.UserGuid,
                u.DisplayName,
                u.Email,
                Role = u.Role.ToString(),
                u.HasPhoto,
                u.LastSeenAt,
            })
            .ToListAsync(ct);

        var ids = rows.Select(r => r.Id).ToList();
        var ownerIds = await _db.VenueOwners
            .Where(o => ids.Contains(o.CreateUserId))
            .Select(o => o.CreateUserId)
            .Distinct()
            .ToHashSetAsync(ct);

        var activeEventOwnerIds = await _db.Venues
            .Where(v => ids.Contains(v.CreateUserId)
                        && v.Type == VenueType.Event
                        && v.Status == VenueStatus.Active)
            .Select(v => v.CreateUserId)
            .Distinct()
            .ToHashSetAsync(ct);

        return rows
            .Select(r => new AdminUserDto(
                r.UserGuid,
                r.DisplayName,
                r.Email,
                r.Role,
                ownerIds.Contains(r.Id),
                activeEventOwnerIds.Contains(r.Id),
                r.HasPhoto,
                r.LastSeenAt))
            .ToList();
    }

    public async Task<IReadOnlyList<AdminVenueDto>> ListVenuesAsync(string? search, CancellationToken ct = default)
    {
        var rows = await _db.Venues
            .Where(v => v.Type == VenueType.Global)
            .GroupJoin(_db.Users, v => v.CreateUserId, u => u.Id, (v, users) => new { v, users })
            .SelectMany(x => x.users.DefaultIfEmpty(), (x, u) => new { x.v, CreatorName = u != null ? u.DisplayName : null })
            .GroupJoin(_db.VenueOwners, x => x.v.OwnerId, o => o.Id, (x, owners) => new { x, owners })
            .SelectMany(x => x.owners.DefaultIfEmpty(), (x, o) => new AdminVenueDto(
                x.x.v.VenueGuid,
                x.x.v.Name,
                x.x.v.Type.ToString(),
                x.x.v.Status.ToString(),
                x.x.v.EventType.ToString(),
                x.x.v.HasPhoto,
                x.x.CreatorName,
                o != null ? o.Name : null,
                x.x.v.CreatedAt))
            .ToListAsync(ct);

        return FilterBySearch(rows, search, x => x.Name, x => x.CreatorName, x => x.OwnerName, x => x.VenueGuid.ToString())
            .Take(200)
            .ToList();
    }

    public async Task<IReadOnlyList<AdminEventDto>> ListEventsAsync(string? search, CancellationToken ct = default)
    {
        var rows = await _db.Venues
            .Where(v => v.Type == VenueType.Event)
            .GroupJoin(_db.Users, v => v.CreateUserId, u => u.Id, (v, users) => new { v, users })
            .SelectMany(x => x.users.DefaultIfEmpty(), (x, u) => new { x.v, CreatorName = u != null ? u.DisplayName : null })
            .GroupJoin(_db.VenueOwners, x => x.v.OwnerId, o => o.Id, (x, owners) => new { x, owners })
            .SelectMany(x => x.owners.DefaultIfEmpty(), (x, o) => new AdminEventDto(
                x.x.v.VenueGuid,
                x.x.v.Name,
                x.x.v.Status.ToString(),
                x.x.v.EventType.ToString(),
                x.x.v.IsPaused,
                x.x.v.HasPhoto,
                x.x.CreatorName,
                o != null ? o.Name : null,
                x.x.v.StartsAt,
                x.x.v.CreatedAt))
            .ToListAsync(ct);

        return FilterBySearch(rows, search, x => x.Name, x => x.CreatorName, x => x.OwnerName, x => x.VenueGuid.ToString())
            .Take(200)
            .ToList();
    }

    public async Task<bool> DeleteVenueHardAsync(Guid venueGuid, CancellationToken ct = default)
    {
        var venue = await _db.Venues
            .Where(v => v.VenueGuid == venueGuid)
            .Select(v => new { v.Id, v.Type })
            .FirstOrDefaultAsync(ct);
        if (venue is null) return false;
        if (venue.Type == VenueType.Global) return false;

        await using var tx = await _db.Database.BeginTransactionAsync(ct);
        await HardDeleteVenueByIdAsync(venue.Id, ct);
        await tx.CommitAsync(ct);
        return true;
    }

    public async Task<bool> DeleteEventHardAsync(Guid venueGuid, CancellationToken ct = default)
    {
        var venue = await _db.Venues
            .Where(v => v.VenueGuid == venueGuid && v.Type == VenueType.Event)
            .Select(v => new { v.Id })
            .FirstOrDefaultAsync(ct);
        if (venue is null) return false;

        await using var tx = await _db.Database.BeginTransactionAsync(ct);
        await HardDeleteVenueByIdAsync(venue.Id, ct);
        await tx.CommitAsync(ct);
        return true;
    }

    public async Task<bool> DeleteUserHardAsync(Guid userGuid, CancellationToken ct = default)
    {
        var user = await _db.Users
            .Where(u => u.UserGuid == userGuid)
            .Select(u => new { u.Id, u.Role })
            .FirstOrDefaultAsync(ct);
        if (user is null) return false;
        if (user.Role == UserRole.Admin) return false;

        await using var tx = await _db.Database.BeginTransactionAsync(ct);

        var ownerIds = await _db.VenueOwners
            .Where(o => o.CreateUserId == user.Id)
            .Select(o => o.Id)
            .ToListAsync(ct);

        var venueIds = await _db.Venues
            .Where(v => v.CreateUserId == user.Id || (v.OwnerId.HasValue && ownerIds.Contains(v.OwnerId.Value)))
            .Select(v => v.Id)
            .Distinct()
            .ToListAsync(ct);

        foreach (var venueId in venueIds)
            await HardDeleteVenueByIdAsync(venueId, ct);

        var matchIds = await _db.Matches
            .Where(m => m.UserAId == user.Id || m.UserBId == user.Id)
            .Select(m => m.Id)
            .ToListAsync(ct);
        if (matchIds.Count > 0)
            await _db.ChatMessages.Where(c => matchIds.Contains(c.MatchId)).ExecuteDeleteAsync(ct);

        await _db.Matches.Where(m => m.UserAId == user.Id || m.UserBId == user.Id).ExecuteDeleteAsync(ct);
        await _db.VenueMemberships.Where(m => m.UserId == user.Id).ExecuteDeleteAsync(ct);
        await _db.Swipes.Where(s => s.FromUserId == user.Id || s.ToUserId == user.Id).ExecuteDeleteAsync(ct);
        await _db.AmbientSwipes.Where(s => s.FromUserId == user.Id).ExecuteDeleteAsync(ct);
        await _db.ChatMessages.Where(c => c.FromUserId == user.Id).ExecuteDeleteAsync(ct);
        await _db.UserPhotos.Where(p => p.UserId == user.Id).ExecuteDeleteAsync(ct);

        await _db.VenueOwnershipClaims
            .Where(c => c.RequestUserId == user.Id || (c.CreatedVenueOwnerId.HasValue && ownerIds.Contains(c.CreatedVenueOwnerId.Value)))
            .ExecuteDeleteAsync(ct);

        if (ownerIds.Count > 0)
        {
            await _db.VenueOwnerEventLogs.Where(l => ownerIds.Contains(l.VenueOwnerId)).ExecuteDeleteAsync(ct);
            await _db.VenueOwnerPhotos.Where(p => ownerIds.Contains(p.VenueOwnerId)).ExecuteDeleteAsync(ct);
            await _db.VenueOwners.Where(o => ownerIds.Contains(o.Id)).ExecuteDeleteAsync(ct);
        }

        await _db.Users.Where(u => u.Id == user.Id).ExecuteDeleteAsync(ct);

        await tx.CommitAsync(ct);
        return true;
    }

    private async Task HardDeleteVenueByIdAsync(long venueId, CancellationToken ct)
    {
        var matchIds = await _db.Matches
            .Where(m => m.VenueId == venueId)
            .Select(m => m.Id)
            .ToListAsync(ct);

        if (matchIds.Count > 0)
            await _db.ChatMessages.Where(c => matchIds.Contains(c.MatchId)).ExecuteDeleteAsync(ct);

        await _db.Matches.Where(m => m.VenueId == venueId).ExecuteDeleteAsync(ct);
        await _db.VenueMemberships.Where(m => m.VenueId == venueId).ExecuteDeleteAsync(ct);
        await _db.Swipes.Where(s => s.VenueId == venueId).ExecuteDeleteAsync(ct);
        await _db.AmbientSwipes.Where(s => s.VenueId == venueId).ExecuteDeleteAsync(ct);
        await _db.VenueAmbientAssignments.Where(a => a.VenueId == venueId).ExecuteDeleteAsync(ct);
        await _db.VenueStats.Where(s => s.VenueId == venueId).ExecuteDeleteAsync(ct);
        await _db.VenuePhotos.Where(p => p.VenueId == venueId).ExecuteDeleteAsync(ct);
        await _db.VenueOwnerEventLogs.Where(l => l.VenueId == venueId).ExecuteDeleteAsync(ct);
        await _db.Venues.Where(v => v.Id == venueId).ExecuteDeleteAsync(ct);
    }

    private static IEnumerable<T> FilterBySearch<T>(
        IEnumerable<T> source,
        string? search,
        params Func<T, string?>[] selectors)
    {
        if (string.IsNullOrWhiteSpace(search)) return source;
        var s = search.Trim();
        return source.Where(x => selectors.Any(sel => (sel(x) ?? string.Empty).Contains(s, StringComparison.OrdinalIgnoreCase)));
    }
}
