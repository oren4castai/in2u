using In2U.Api.Common;

namespace In2U.Api.Services;

public interface IPushService
{
    Task SendToUserAsync(long userId, PushNotification notification, CancellationToken ct = default);
    Task SendToUserGuidAsync(Guid userGuid, PushNotification notification, CancellationToken ct = default);
}
