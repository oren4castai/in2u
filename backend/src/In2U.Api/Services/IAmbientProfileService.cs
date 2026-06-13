using In2U.Api.Dtos.Ambient;

namespace In2U.Api.Services;

public interface IAmbientProfileService
{
    Task<IReadOnlyList<AmbientPreviewDto>> GetVenuePreviewAsync(long venueId, int? max = null, CancellationToken ct = default);
    Task<IReadOnlyList<AmbientFeedItem>> GetFeedAmbientAsync(long venueId, int realCandidateCount, int totalSlots, CancellationToken ct = default);
    Task<bool> IsAmbientGuidAsync(Guid candidateGuid, CancellationToken ct = default);
    Task RotateAllAsync(CancellationToken ct);
    Task ReplaceCatalogAsync(IEnumerable<AmbientProfileSeed> profiles, CancellationToken ct = default);
    Task SeedDefaultsIfEmptyAsync(CancellationToken ct = default);
}
