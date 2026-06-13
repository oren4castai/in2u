namespace In2U.Api.Services;

public interface ISessionPurgeService
{
    Task PurgeSessionDataAsync(long userId, CancellationToken ct = default);
}
