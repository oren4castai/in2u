using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Ambient;
using In2U.Api.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace In2U.Api.Services;

public sealed class AmbientProfileService : IAmbientProfileService
{
    private readonly AppDbContext _db;
    private readonly AmbientOptions _opts;
    private readonly ILogger<AmbientProfileService> _log;
    private static readonly Random _rng = new();

    public AmbientProfileService(
        AppDbContext db,
        IOptions<AmbientOptions> opts,
        ILogger<AmbientProfileService> log)
    {
        _db = db;
        _opts = opts.Value;
        _log = log;
    }

    public async Task<IReadOnlyList<AmbientPreviewDto>> GetVenuePreviewAsync(
        long venueId, int? max = null, CancellationToken ct = default)
    {
        var take = max ?? _opts.PreviewAvatarCount;
        if (take <= 0) return Array.Empty<AmbientPreviewDto>();

        var rows = await _db.VenueAmbientAssignments
            .AsNoTracking()
            .Where(a => a.VenueId == venueId && a.Active)
            .OrderByDescending(a => a.AssignedAt)
            .Join(_db.AmbientProfiles.AsNoTracking(),
                a => a.AmbientProfileId, p => p.Id,
                (a, p) => new { p.AmbientProfileGuid, p.PictureUrl, p.BlurLevel, p.DisplayName })
            .Take(take)
            .ToListAsync(ct);

        return rows
            .Select(r => new AmbientPreviewDto(r.AmbientProfileGuid, r.PictureUrl, r.BlurLevel, r.DisplayName))
            .ToList();
    }

    public async Task<IReadOnlyList<AmbientFeedItem>> GetFeedAmbientAsync(
        long venueId, int realCandidateCount, int totalSlots, CancellationToken ct = default)
    {
        if (totalSlots <= 0) return Array.Empty<AmbientFeedItem>();

        double ratio = realCandidateCount <= 2
            ? _opts.LowDensityAmbientRatio
            : realCandidateCount <= 14
                ? _opts.MedDensityAmbientRatio
                : _opts.HighDensityAmbientRatio;

        var ambientCount = (int)Math.Ceiling(totalSlots * ratio);
        if (ambientCount < 0) ambientCount = 0;
        if (ambientCount > totalSlots) ambientCount = totalSlots;
        if (ambientCount == 0) return Array.Empty<AmbientFeedItem>();

        var rows = await _db.VenueAmbientAssignments
            .AsNoTracking()
            .Where(a => a.VenueId == venueId && a.Active)
            .Join(_db.AmbientProfiles.AsNoTracking().Where(p => p.Active),
                a => a.AmbientProfileId, p => p.Id,
                (a, p) => new
                {
                    p.AmbientProfileGuid,
                    p.DisplayName,
                    p.PictureUrl,
                    p.BlurLevel,
                    p.AgeRange,
                    p.StyleTags,
                })
            .OrderBy(_ => Guid.NewGuid())
            .Take(ambientCount)
            .ToListAsync(ct);

        return rows
            .Select(r => new AmbientFeedItem(
                r.AmbientProfileGuid,
                r.DisplayName,
                r.PictureUrl,
                r.BlurLevel,
                r.AgeRange,
                r.StyleTags ?? new List<string>()))
            .ToList();
    }

    public Task<bool> IsAmbientGuidAsync(Guid candidateGuid, CancellationToken ct = default)
    {
        return _db.AmbientProfiles
            .AsNoTracking()
            .AnyAsync(a => a.AmbientProfileGuid == candidateGuid && a.Active, ct);
    }

    public async Task RotateAllAsync(CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var ttl = TimeSpan.FromMinutes(Math.Max(1, _opts.AssignmentTtlMinutes));

        // 1) Expire stale active assignments.
        var expired = await _db.VenueAmbientAssignments
            .Where(a => a.Active && a.ExpiresAt <= now)
            .ToListAsync(ct);
        foreach (var a in expired) a.Active = false;
        if (expired.Count > 0) await _db.SaveChangesAsync(ct);

        // 2) Top up each active venue toward MinPerVenue / MaxPerVenue.
        var venueIds = await _db.Venues
            .Where(v => v.Status == VenueStatus.Active)
            .Select(v => v.Id)
            .ToListAsync(ct);

        if (venueIds.Count == 0) return;

        var activeProfileIds = await _db.AmbientProfiles
            .Where(p => p.Active)
            .Select(p => p.Id)
            .ToListAsync(ct);
        if (activeProfileIds.Count == 0) return;

        int rotated = 0;
        foreach (var venueId in venueIds)
        {
            ct.ThrowIfCancellationRequested();

            var currentActive = await _db.VenueAmbientAssignments
                .Where(a => a.VenueId == venueId && a.Active)
                .Select(a => a.AmbientProfileId)
                .ToListAsync(ct);

            if (currentActive.Count >= _opts.MinPerVenue) continue;

            var slotsToFill = _opts.MaxPerVenue - currentActive.Count;
            if (slotsToFill <= 0) continue;

            var pool = activeProfileIds.Except(currentActive).ToList();
            if (pool.Count == 0) continue;

            var pick = pool
                .OrderBy(_ => _rng.Next())
                .Take(Math.Min(slotsToFill, pool.Count))
                .ToList();

            foreach (var profileId in pick)
            {
                _db.VenueAmbientAssignments.Add(new VenueAmbientAssignment
                {
                    VenueId = venueId,
                    AmbientProfileId = profileId,
                    AssignedAt = now,
                    ExpiresAt = now.Add(ttl),
                    Active = true,
                });
                rotated++;
            }
        }

        if (rotated > 0)
        {
            try
            {
                await _db.SaveChangesAsync(ct);
                _log.LogInformation("Ambient rotation: expired={Expired}, assigned={Assigned}.", expired.Count, rotated);
            }
            catch (DbUpdateException ex)
            {
                _log.LogWarning(ex, "Ambient rotation: partial save conflict (likely concurrent rotation).");
            }
        }
        else if (expired.Count > 0)
        {
            _log.LogInformation("Ambient rotation: expired={Expired}, assigned=0.", expired.Count);
        }
    }

    public async Task ReplaceCatalogAsync(IEnumerable<AmbientProfileSeed> profiles, CancellationToken ct = default)
    {
        var list = (profiles ?? Array.Empty<AmbientProfileSeed>()).ToList();

        await using var tx = await _db.Database.BeginTransactionAsync(ct);

        var existingAll = await _db.AmbientProfiles.ToListAsync(ct);
        foreach (var p in existingAll) p.Active = false;

        var existingByKey = existingAll.ToDictionary(
            p => (p.DisplayName, p.PictureUrl),
            p => p);

        var now = DateTime.UtcNow;
        foreach (var seed in list)
        {
            if (string.IsNullOrWhiteSpace(seed.DisplayName) || string.IsNullOrWhiteSpace(seed.PictureUrl))
                continue;

            if (existingByKey.TryGetValue((seed.DisplayName, seed.PictureUrl), out var found))
            {
                found.Gender = seed.Gender;
                found.StyleTags = seed.StyleTags ?? new List<string>();
                found.AgeRange = seed.AgeRange;
                found.BlurLevel = seed.BlurLevel;
                found.Active = true;
                found.UpdatedAt = now;
            }
            else
            {
                _db.AmbientProfiles.Add(new AmbientProfile
                {
                    DisplayName = seed.DisplayName,
                    PictureUrl = seed.PictureUrl,
                    Gender = seed.Gender,
                    StyleTags = seed.StyleTags ?? new List<string>(),
                    AgeRange = seed.AgeRange,
                    BlurLevel = seed.BlurLevel,
                    Active = true,
                    CreatedAt = now,
                    UpdatedAt = now,
                });
            }
        }

        await _db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
    }

    public async Task SeedDefaultsIfEmptyAsync(CancellationToken ct = default)
    {
        if (await _db.AmbientProfiles.AnyAsync(ct)) return;

        var seeds = BuildDefaultSeeds();
        var now = DateTime.UtcNow;
        foreach (var seed in seeds)
        {
            _db.AmbientProfiles.Add(new AmbientProfile
            {
                DisplayName = seed.DisplayName,
                PictureUrl = seed.PictureUrl,
                Gender = seed.Gender,
                StyleTags = seed.StyleTags ?? new List<string>(),
                AgeRange = seed.AgeRange,
                BlurLevel = seed.BlurLevel,
                Active = true,
                CreatedAt = now,
                UpdatedAt = now,
            });
        }
        await _db.SaveChangesAsync(ct);
        _log.LogInformation("Seeded {Count} default ambient profiles.", seeds.Count);
    }

    private static List<AmbientProfileSeed> BuildDefaultSeeds()
    {
        // ~70% Low blur, ~30% High blur. Local avatar images with in-app blur.
        string Url(int i) => $"/avatars/{i}.jpg";
        return new List<AmbientProfileSeed>
        {
            new("Avery",   Url(1),  "Female",      new() { "art", "coffee" },        "25-34", AmbientBlurLevel.Low),
            new("Jordan",  Url(2),  "Male",        new() { "music", "vinyl" },       "25-34", AmbientBlurLevel.Low),
            new("Sam",     Url(3),  "Other",       new() { "hiking", "books" },      "30-39", AmbientBlurLevel.Low),
            new("Riley",   Url(4),  "Female",      new() { "yoga", "matcha" },       "21-29", AmbientBlurLevel.Low),
            new("Casey",   Url(5),  "Male",        new() { "tech", "boardgames" },   "28-36", AmbientBlurLevel.High),
            new("Morgan",  Url(6),  "Female",      new() { "fashion", "travel" },    "25-34", AmbientBlurLevel.Low),
            new("Taylor",  Url(7),  "Male",        new() { "cycling", "espresso" },  "30-39", AmbientBlurLevel.Low),
            new("Quinn",   Url(8),  "Other",       new() { "design", "vinyl" },      "22-30", AmbientBlurLevel.High),
        };
    }
}
