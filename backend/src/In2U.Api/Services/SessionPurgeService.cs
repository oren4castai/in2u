using In2U.Api.Data;
using In2U.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace In2U.Api.Services;

public sealed class SessionPurgeService : ISessionPurgeService
{
    private readonly AppDbContext _db;
    private readonly ILocationValidationService _location;
    private readonly IMatchService _matches;
    private readonly ILogger<SessionPurgeService> _log;

    public SessionPurgeService(
        AppDbContext db,
        ILocationValidationService location,
        IMatchService matches,
        ILogger<SessionPurgeService> log)
    {
        _db = db;
        _location = location;
        _matches = matches;
        _log = log;
    }

    public async Task PurgeSessionDataAsync(long userId, CancellationToken ct = default)
    {
        // 1) Force-checkout any active membership through the standard flow:
        //    sets AutoCheckedOut, ends matches for that venue, broadcasts
        //    ForceCheckout + PresenceUpdated, push fallback to other devices.
        try
        {
            await _location.ForceCheckoutActiveAsync(userId, "freshStart", ct);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Fresh-start force checkout failed for user {UserId}.", userId);
        }

        // 2) End ALL remaining matches involving this user (broadcasts MatchEnded
        //    to peers and hard-deletes matches + chat messages in a transaction).
        try
        {
            await _matches.EndAllUserMatchesAsync(userId, MatchEndReason.UserLeft, ct);
        }
        catch (Exception ex)
        {
            _log.LogWarning(ex, "Fresh-start match cleanup failed for user {UserId}.", userId);
        }

        // 3) Pure DB cleanup of historical rows that don't require broadcasts.
        await using var tx = await _db.Database.BeginTransactionAsync(ct);

        await _db.VenueMemberships
            .Where(m => m.UserId == userId)
            .ExecuteDeleteAsync(ct);

        await _db.Swipes
            .Where(s => s.FromUserId == userId || s.ToUserId == userId)
            .ExecuteDeleteAsync(ct);

        await _db.AmbientSwipes
            .Where(s => s.FromUserId == userId)
            .ExecuteDeleteAsync(ct);

        // Defensive: any orphan chat messages authored by this user (should be
        // gone after match hard-delete cascade, but belt-and-suspenders).
        await _db.ChatMessages
            .Where(c => c.FromUserId == userId)
            .ExecuteDeleteAsync(ct);

        await tx.CommitAsync(ct);
    }
}
