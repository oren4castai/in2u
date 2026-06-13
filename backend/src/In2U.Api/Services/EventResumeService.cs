using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SessionOptions = In2U.Api.Common.SessionOptions;

namespace In2U.Api.Services;

public sealed class EventResumeService : IEventResumeService
{
    private readonly AppDbContext _db;
    private readonly SessionOptions _session;

    public EventResumeService(AppDbContext db, IOptions<SessionOptions> sessionOptions)
    {
        _db = db;
        _session = sessionOptions.Value;
    }

    public async Task<bool> IsEligibleAsync(long userId, CancellationToken ct = default)
    {
        var active = await _db.VenueMemberships
            .Where(m => m.UserId == userId)
            .Join(_db.Venues, m => m.VenueId, v => v.Id, (m, v) => new { m, v })
            .Select(x => new
            {
                x.m.LastActiveAtUtc,
                x.v.Type,
                x.v.Status,
                x.v.StartsAt,
                x.v.DurationHours,
            })
            .FirstOrDefaultAsync(ct);

        if (active is null)
            return false;

        if (active.Type != VenueType.Event)
            return false;

        if (active.Status != VenueStatus.Active)
            return false;

        var now = DateTime.UtcNow;
        if (active.StartsAt.HasValue && active.DurationHours.HasValue)
        {
            var endsAt = active.StartsAt.Value.AddHours(active.DurationHours.Value);
            if (endsAt <= now)
                return false;
        }

        if (!active.LastActiveAtUtc.HasValue)
            return false;

        var resumeWindow = Math.Max(1, _session.ResumeWindowMinutes);
        return now - active.LastActiveAtUtc.Value <= TimeSpan.FromMinutes(resumeWindow);
    }
}
