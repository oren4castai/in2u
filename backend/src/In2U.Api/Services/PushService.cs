using In2U.Api.Common;

namespace In2U.Api.Services;

public sealed class PushService : IPushService
{
    public Task SendToUserGuidAsync(Guid userGuid, PushNotification notification, CancellationToken ct = default)
        => Task.CompletedTask;

    public Task SendToUserAsync(long userId, PushNotification notification, CancellationToken ct = default)
        => Task.CompletedTask;
}
