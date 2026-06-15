using In2U.Api.Common;
using In2U.Api.Dtos.Owners;
using In2U.Api.Entities;

namespace In2U.Api.Services;

public enum ClaimActionResult { Ok, NotFound, NotPending }

public enum OwnerEventActionResult { Ok, NoOwner, NotGoverned, NotFound }

public sealed record EventGovernanceResult(long? OwnerId, bool Allowed, string? RejectMessage);

public interface IVenueOwnershipService
{
    Task<Result<SubmitClaimResponse>> SubmitClaimAsync(
        long requestUserId, string name, string contactName, string contactPhone,
        double lat, double lng, int radiusM,
        byte[] photoData, string photoContentType, CancellationToken ct = default);

    Task<IReadOnlyList<PendingClaimDto>> ListPendingClaimsAsync(CancellationToken ct = default);

    Task<ClaimActionResult> ApproveClaimAsync(Guid claimGuid, CancellationToken ct = default);

    Task<ClaimActionResult> RejectClaimAsync(Guid claimGuid, string? note, CancellationToken ct = default);

    Task<IReadOnlyList<OwnerVenueSummaryDto>> ListOwnedVenuesAsync(long ownerUserId, CancellationToken ct = default);

    Task<OwnerVenueDetailDto?> GetVenueDetailAsync(long ownerUserId, Guid ownerGuid, CancellationToken ct = default);

    Task<IReadOnlyList<MyClaimDto>> ListMyClaimsAsync(long requestUserId, CancellationToken ct = default);

    Task<OwnerEventActionResult> CloseEventAsync(
        long ownerUserId, Guid venueGuid, CancellationToken ct = default);

    Task<OwnerEventActionResult> DeleteEventAsync(
        long ownerUserId, Guid venueGuid, CancellationToken ct = default);

    Task<OwnerEventActionResult> RescheduleEventAsync(
        long ownerUserId, Guid venueGuid, DateTime startsAt, CancellationToken ct = default);

    Task<OwnerEventActionResult> VerifyGovernedEventAsync(
        long ownerUserId, Guid venueGuid, CancellationToken ct = default);

    Task<EventGovernanceResult> EvaluateEventCreationAsync(
        double lat, double lng, VenueEventType eventType, long creatorUserId, CancellationToken ct = default);

    Task<GovernancePreviewDto> PreviewGovernanceAsync(
        double lat, double lng, long callerUserId, CancellationToken ct = default);

    Task InheritOwnerPhotoAsync(long ownerId, long venueId, CancellationToken ct = default);

    Task<bool> DeletePastEventAsync(long ownerUserId, Guid ownerGuid, long logId, CancellationToken ct = default);

    Task<bool> DeleteVenueAsync(long ownerUserId, Guid ownerGuid, CancellationToken ct = default);
}
