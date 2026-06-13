using In2U.Api.Common;
using In2U.Api.Data;
using In2U.Api.Dtos.Owners;
using In2U.Api.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace In2U.Api.Services;

public sealed class VenueOwnershipService : IVenueOwnershipService
{
    private readonly AppDbContext _db;
    private readonly OwnerOptions _owner;
    private readonly IVenueService _venueService;

    public VenueOwnershipService(AppDbContext db, IOptions<OwnerOptions> ownerOpts, IVenueService venueService)
    {
        _db = db;
        _owner = ownerOpts.Value;
        _venueService = venueService;
    }

    public async Task<Result<SubmitClaimResponse>> SubmitClaimAsync(
        long requestUserId, string name, string contactName, string contactPhone,
        double lat, double lng, int radiusM,
        byte[] photoData, string photoContentType, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(name))
            return Result<SubmitClaimResponse>.Failure("Name is required.");
        if (string.IsNullOrWhiteSpace(contactName))
            return Result<SubmitClaimResponse>.Failure("Contact name is required.");
        if (string.IsNullOrWhiteSpace(contactPhone))
            return Result<SubmitClaimResponse>.Failure("Contact phone is required.");
        if (radiusM < 10 || radiusM > 5000)
            return Result<SubmitClaimResponse>.Failure("RadiusM must be between 10 and 5000.");
        if (photoData.Length == 0)
            return Result<SubmitClaimResponse>.Failure("A photo is required.");

        var claim = new VenueOwnershipClaim
        {
            RequestUserId = requestUserId,
            Name = name.Trim(),
            ContactName = contactName.Trim(),
            ContactPhone = contactPhone.Trim(),
            Lat = lat,
            Lng = lng,
            RadiusM = radiusM,
            PhotoData = photoData,
            PhotoContentType = photoContentType,
            Status = ClaimStatus.Pending,
            CreatedAt = DateTime.UtcNow,
        };
        _db.VenueOwnershipClaims.Add(claim);
        await _db.SaveChangesAsync(ct);
        return Result<SubmitClaimResponse>.Success(new SubmitClaimResponse(claim.ClaimGuid));
    }

    public async Task<IReadOnlyList<PendingClaimDto>> ListPendingClaimsAsync(CancellationToken ct = default)
    {
        var claims = await _db.VenueOwnershipClaims
            .Where(c => c.Status == ClaimStatus.Pending)
            .OrderBy(c => c.CreatedAt)
            .ToListAsync(ct);

        var owners = await _db.VenueOwners
            .Select(o => new { o.Id, o.VenueOwnerGuid, o.Name, o.Lat, o.Lng, o.RadiusM })
            .ToListAsync(ct);

        var regions = owners.Select(o => new OwnerRegion(o.Id, o.Lat, o.Lng, o.RadiusM)).ToList();

        var result = new List<PendingClaimDto>(claims.Count);
        foreach (var c in claims)
        {
            var conflicts = new List<ClaimConflictDto>();

            var nearIds = new HashSet<long>();
            foreach (var (id, dist) in GeoMath.OwnersWithin(c.Lat, c.Lng, _owner.ConflictThresholdM, regions))
            {
                var o = owners.First(x => x.Id == id);
                conflicts.Add(new ClaimConflictDto(o.VenueOwnerGuid, o.Name, dist, "geo"));
                nearIds.Add(id);
            }

            foreach (var o in owners.Where(o => !nearIds.Contains(o.Id)
                && string.Equals(o.Name, c.Name, StringComparison.OrdinalIgnoreCase)))
            {
                var dist = GeoMath.DistanceMeters(c.Lat, c.Lng, o.Lat, o.Lng);
                conflicts.Add(new ClaimConflictDto(o.VenueOwnerGuid, o.Name, dist, "name"));
            }

            result.Add(new PendingClaimDto(
                c.ClaimGuid, c.Name, c.ContactName, c.ContactPhone, c.Lat, c.Lng, c.RadiusM, c.CreatedAt, conflicts));
        }
        return result;
    }

    public async Task<ClaimActionResult> ApproveClaimAsync(Guid claimGuid, CancellationToken ct = default)
    {
        var claim = await _db.VenueOwnershipClaims.FirstOrDefaultAsync(c => c.ClaimGuid == claimGuid, ct);
        if (claim is null) return ClaimActionResult.NotFound;
        if (claim.Status != ClaimStatus.Pending) return ClaimActionResult.NotPending;

        var owner = new VenueOwner
        {
            CreateUserId = claim.RequestUserId,
            Lat = claim.Lat,
            Lng = claim.Lng,
            RadiusM = claim.RadiusM,
            Name = claim.Name,
            AllowPublicEventsCount = _owner.DefaultAllowPublicEventsCount,
            HasPhoto = claim.PhotoData.Length > 0,
        };
        _db.VenueOwners.Add(owner);
        await _db.SaveChangesAsync(ct);

        if (claim.PhotoData.Length > 0)
        {
            _db.VenueOwnerPhotos.Add(new VenueOwnerPhoto
            {
                VenueOwnerId = owner.Id,
                Data = claim.PhotoData,
                ContentType = claim.PhotoContentType,
                UpdatedAt = DateTime.UtcNow,
            });
        }

        claim.Status = ClaimStatus.Approved;
        claim.CreatedVenueOwnerId = owner.Id;
        await _db.SaveChangesAsync(ct);
        return ClaimActionResult.Ok;
    }

    public async Task<ClaimActionResult> RejectClaimAsync(Guid claimGuid, string? note, CancellationToken ct = default)
    {
        var claim = await _db.VenueOwnershipClaims.FirstOrDefaultAsync(c => c.ClaimGuid == claimGuid, ct);
        if (claim is null) return ClaimActionResult.NotFound;
        if (claim.Status != ClaimStatus.Pending) return ClaimActionResult.NotPending;

        claim.Status = ClaimStatus.Rejected;
        claim.AdminNote = note;
        // Free the stored image bytes; the claim row is kept as an audit record.
        claim.PhotoData = Array.Empty<byte>();
        await _db.SaveChangesAsync(ct);
        return ClaimActionResult.Ok;
    }

    public async Task<IReadOnlyList<OwnerVenueSummaryDto>> ListOwnedVenuesAsync(
        long ownerUserId, CancellationToken ct = default)
    {
        var owners = await _db.VenueOwners
            .Where(o => o.CreateUserId == ownerUserId)
            .OrderBy(o => o.Id)
            .ToListAsync(ct);
        if (owners.Count == 0) return Array.Empty<OwnerVenueSummaryDto>();

        var ownerIds = owners.Select(o => o.Id).ToList();

        var activeVenues = await _db.Venues
            .Where(v => v.OwnerId != null && ownerIds.Contains(v.OwnerId.Value)
                        && v.Type == VenueType.Event
                        && v.Status == VenueStatus.Active)
            .Select(v => new { v.Id, OwnerId = v.OwnerId!.Value })
            .ToListAsync(ct);

        var venueIds = activeVenues.Select(v => v.Id).ToList();
        var liveByVenue = await _db.VenueMemberships
            .Where(m => venueIds.Contains(m.VenueId))
            .GroupBy(m => m.VenueId)
            .Select(g => new { VenueId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.VenueId, x => x.Count, ct);

        return owners.Select(o =>
        {
            var ownerVenues = activeVenues.Where(v => v.OwnerId == o.Id).ToList();
            var live = ownerVenues.Sum(v => liveByVenue.TryGetValue(v.Id, out var c) ? c : 0);
            return new OwnerVenueSummaryDto(
                o.VenueOwnerGuid, o.Name, ownerVenues.Count, live, o.HasPhoto);
        }).ToList();
    }

    public async Task<OwnerVenueDetailDto?> GetVenueDetailAsync(
        long ownerUserId, Guid ownerGuid, CancellationToken ct = default)
    {
        var owner = await _db.VenueOwners
            .FirstOrDefaultAsync(o => o.VenueOwnerGuid == ownerGuid, ct);
        if (owner is null || owner.CreateUserId != ownerUserId) return null;

        var activeRaw = await _db.Venues
            .Where(v => v.OwnerId == owner.Id && v.Type == VenueType.Event && v.Status == VenueStatus.Active)
            .GroupJoin(_db.VenueStats, v => v.Id, s => s.VenueId, (v, stats) => new { v, stats })
            .SelectMany(x => x.stats.DefaultIfEmpty(), (x, s) => new
            {
                x.v.Id,
                x.v.VenueGuid,
                x.v.Name,
                x.v.Status,
                x.v.IsPaused,
                x.v.CreateUserId,
                x.v.StartsAt,
                x.v.DurationHours,
                Joined = s != null ? s.JoinedCount : 0,
                Matches = s != null ? s.MatchesCount : 0,
                Views = s != null ? s.ViewsCount : 0,
            })
            .ToListAsync(ct);

        var activeVenueIds = activeRaw.Select(x => x.Id).ToList();
        var liveByVenue = await _db.VenueMemberships
            .Where(m => activeVenueIds.Contains(m.VenueId))
            .GroupBy(m => m.VenueId)
            .Select(g => new { VenueId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.VenueId, x => x.Count, ct);

        var activeEvents = activeRaw.Select(x => new OwnerActiveEventDto(
            x.VenueGuid,
            x.Name,
            x.Status.ToString(),
            x.IsPaused,
            x.CreateUserId == ownerUserId,
            x.StartsAt,
            x.DurationHours,
            liveByVenue.TryGetValue(x.Id, out var c) ? c : 0,
            x.Joined,
            x.Matches,
            x.Views)).ToList();

        var pastEvents = await _db.VenueOwnerEventLogs
            .Where(l => l.VenueOwnerId == owner.Id)
            .OrderByDescending(l => l.ClosedAt)
            .Select(l => new OwnerPastEventDto(
                l.Id, l.Name, l.ClosedAt, l.JoinedCount, l.MatchesCount, l.ViewsCount))
            .ToListAsync(ct);

        var totals = new OwnerAccumulatedTotalsDto(
            activeEvents.Sum(e => e.JoinedCount) + pastEvents.Sum(e => e.JoinedCount),
            activeEvents.Sum(e => e.MatchesCount) + pastEvents.Sum(e => e.MatchesCount),
            activeEvents.Sum(e => e.ViewsCount) + pastEvents.Sum(e => e.ViewsCount));

        return new OwnerVenueDetailDto(
            owner.VenueOwnerGuid,
            owner.Name,
            owner.Lat,
            owner.Lng,
            owner.RadiusM,
            owner.AllowPublicEventsCount,
            owner.HasPhoto,
            totals,
            activeEvents,
            pastEvents);
    }

    public async Task<IReadOnlyList<MyClaimDto>> ListMyClaimsAsync(
        long requestUserId, CancellationToken ct = default)
    {
        return await _db.VenueOwnershipClaims
            .Where(c => c.RequestUserId == requestUserId)
            .OrderByDescending(c => c.CreatedAt)
            .Select(c => new MyClaimDto(
                c.ClaimGuid, c.Name, c.Lat, c.Lng, c.RadiusM,
                c.Status.ToString(), c.AdminNote, c.CreatedAt))
            .ToListAsync(ct);
    }

    public async Task<bool> DeletePastEventAsync(
        long ownerUserId, Guid ownerGuid, long logId, CancellationToken ct = default)
    {
        var owner = await _db.VenueOwners
            .FirstOrDefaultAsync(o => o.VenueOwnerGuid == ownerGuid && o.CreateUserId == ownerUserId, ct);
        if (owner is null) return false;

        var deleted = await _db.VenueOwnerEventLogs
            .Where(l => l.Id == logId && l.VenueOwnerId == owner.Id)
            .ExecuteDeleteAsync(ct);
        return deleted > 0;
    }

    public async Task<bool> DeleteVenueAsync(
        long ownerUserId, Guid ownerGuid, CancellationToken ct = default)
    {
        var owner = await _db.VenueOwners
            .FirstOrDefaultAsync(o => o.VenueOwnerGuid == ownerGuid && o.CreateUserId == ownerUserId, ct);
        if (owner is null) return false;

        // Close all active events under this venue (handles member cleanup, matches, presence, etc.)
        var activeVenueGuids = await _db.Venues
            .Where(v => v.OwnerId == owner.Id && v.Status == VenueStatus.Active)
            .Select(v => v.VenueGuid)
            .ToListAsync(ct);
        foreach (var vg in activeVenueGuids)
            await _venueService.CloseAsync(vg, ct);

        // Hard-delete all owner data
        await _db.VenueOwnerEventLogs.Where(l => l.VenueOwnerId == owner.Id).ExecuteDeleteAsync(ct);
        await _db.VenueOwnerPhotos.Where(p => p.VenueOwnerId == owner.Id).ExecuteDeleteAsync(ct);
        await _db.VenueOwners.Where(o => o.Id == owner.Id).ExecuteDeleteAsync(ct);

        return true;
    }

    public async Task<OwnerEventActionResult> SetEventPausedAsync(
        long ownerUserId, Guid venueGuid, bool paused, CancellationToken ct = default)
    {
        var check = await ResolveGovernedEventAsync(ownerUserId, venueGuid, ct);
        if (check.Result != OwnerEventActionResult.Ok) return check.Result;

        check.Venue!.IsPaused = paused;
        await _db.SaveChangesAsync(ct);
        return OwnerEventActionResult.Ok;
    }

    public async Task<OwnerEventActionResult> VerifyGovernedEventAsync(
        long ownerUserId, Guid venueGuid, CancellationToken ct = default)
    {
        var check = await ResolveGovernedEventAsync(ownerUserId, venueGuid, ct);
        return check.Result;
    }

    public async Task<EventGovernanceResult> EvaluateEventCreationAsync(
        double lat, double lng, VenueEventType eventType, long creatorUserId, CancellationToken ct = default)
    {
        var owners = await _db.VenueOwners
            .Select(o => new { o.Id, o.Lat, o.Lng, o.RadiusM, o.CreateUserId, o.AllowPublicEventsCount })
            .ToListAsync(ct);
        if (owners.Count == 0) return new EventGovernanceResult(null, true, null);

        var regions = owners.Select(o => new OwnerRegion(o.Id, o.Lat, o.Lng, o.RadiusM));
        var ownerId = GeoMath.NearestGoverningOwner(lat, lng, regions);
        if (ownerId is null) return new EventGovernanceResult(null, true, null);

        var owner = owners.First(o => o.Id == ownerId.Value);

        if (eventType == VenueEventType.Private)
            return new EventGovernanceResult(ownerId, false, "Private events are not allowed in this venue.");

        // The owner's own events are unrestricted and excluded from the quota count.
        if (creatorUserId == owner.CreateUserId)
            return new EventGovernanceResult(ownerId, true, null);

        var activePublic = await _db.Venues.CountAsync(v =>
            v.OwnerId == owner.Id
            && v.Type == VenueType.Event
            && v.Status == VenueStatus.Active
            && v.EventType == VenueEventType.Public
            && v.CreateUserId != owner.CreateUserId, ct);

        if (activePublic >= owner.AllowPublicEventsCount)
            return new EventGovernanceResult(ownerId, false, "This venue has reached its public event limit.");

        return new EventGovernanceResult(ownerId, true, null);
    }

    public async Task<GovernancePreviewDto> PreviewGovernanceAsync(
        double lat, double lng, long callerUserId, CancellationToken ct = default)
    {
        var owners = await _db.VenueOwners
            .Select(o => new { o.Id, o.Lat, o.Lng, o.RadiusM, o.Name, o.CreateUserId, o.AllowPublicEventsCount })
            .ToListAsync(ct);
        if (owners.Count == 0) return new GovernancePreviewDto(false, null, true, null);

        var regions = owners.Select(o => new OwnerRegion(o.Id, o.Lat, o.Lng, o.RadiusM));
        var ownerId = GeoMath.NearestGoverningOwner(lat, lng, regions);
        if (ownerId is null) return new GovernancePreviewDto(false, null, true, null);

        var owner = owners.First(o => o.Id == ownerId.Value);

        // The owner's own events are unrestricted inside their venue.
        if (callerUserId == owner.CreateUserId)
            return new GovernancePreviewDto(true, owner.Name, true, null);

        var activePublic = await _db.Venues.CountAsync(v =>
            v.OwnerId == owner.Id
            && v.Type == VenueType.Event
            && v.Status == VenueStatus.Active
            && v.EventType == VenueEventType.Public
            && v.CreateUserId != owner.CreateUserId, ct);

        var remaining = Math.Max(0, owner.AllowPublicEventsCount - activePublic);
        return new GovernancePreviewDto(true, owner.Name, false, remaining);
    }

    public async Task InheritOwnerPhotoAsync(long ownerId, long venueId, CancellationToken ct = default)
    {
        var photo = await _db.VenueOwnerPhotos.FirstOrDefaultAsync(p => p.VenueOwnerId == ownerId, ct);
        if (photo is null || photo.Data.Length == 0) return;

        var existing = await _db.VenuePhotos.FirstOrDefaultAsync(p => p.VenueId == venueId, ct);
        if (existing is not null)
        {
            existing.Data = photo.Data;
            existing.ContentType = photo.ContentType;
            existing.UpdatedAt = DateTime.UtcNow;
        }
        else
        {
            _db.VenuePhotos.Add(new VenuePhoto
            {
                VenueId = venueId,
                Data = photo.Data,
                ContentType = photo.ContentType,
                UpdatedAt = DateTime.UtcNow,
            });
        }

        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.Id == venueId, ct);
        if (venue is not null) venue.HasPhoto = true;
        await _db.SaveChangesAsync(ct);
    }

    private async Task<(OwnerEventActionResult Result, Venue? Venue)> ResolveGovernedEventAsync(
        long ownerUserId, Guid venueGuid, CancellationToken ct)
    {
        var owner = await _db.VenueOwners
            .Where(o => o.CreateUserId == ownerUserId)
            .OrderBy(o => o.Id)
            .FirstOrDefaultAsync(ct);
        if (owner is null) return (OwnerEventActionResult.NoOwner, null);

        var venue = await _db.Venues.FirstOrDefaultAsync(v => v.VenueGuid == venueGuid, ct);
        if (venue is null) return (OwnerEventActionResult.NotFound, null);
        if (venue.OwnerId != owner.Id) return (OwnerEventActionResult.NotGoverned, null);

        return (OwnerEventActionResult.Ok, venue);
    }
}
