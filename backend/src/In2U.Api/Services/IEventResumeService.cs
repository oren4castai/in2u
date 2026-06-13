namespace In2U.Api.Services;

public interface IEventResumeService
{
    Task<bool> IsEligibleAsync(long userId, CancellationToken ct = default);
}
