namespace In2U.Api.Services;

internal static class PushHelpers
{
    public static void TryPushVenueAnnouncement(
        IPushService push,
        ILogger log,
        Guid recipientGuid,
        Guid venueGuid,
        string message)
    {
        var notification = new In2U.Api.Common.PushNotification(
            "Venue announcement",
            message,
            new Dictionary<string, string>
            {
                ["type"] = "venue_announcement",
                ["venueGuid"] = venueGuid.ToString(),
                ["body"] = message,
            });

        _ = Task.Run(async () =>
        {
            try
            {
                await push.SendToUserGuidAsync(recipientGuid, notification, CancellationToken.None);
            }
            catch (Exception ex)
            {
                log.LogWarning(ex, "Push for venue announcement failed.");
            }
        });
    }

    public static void TryPushCheckout(
        IPushService push,
        ILogger log,
        Guid recipientGuid,
        Guid venueGuid,
        string reason)
    {
        var body = reason switch
        {
            "outOfRadius" => "You left the venue area.",
            "venueClosed" => "The venue closed.",
            "inactive" => "You were inactive too long.",
            _ => "You were checked out.",
        };
        var data = new Dictionary<string, string>
        {
            ["type"] = "checkout",
            ["venueGuid"] = venueGuid.ToString(),
            ["reason"] = reason,
        };
        var notification = new In2U.Api.Common.PushNotification(
            "You were checked out",
            body,
            data);
        _ = Task.Run(async () =>
        {
            try
            {
                await push.SendToUserGuidAsync(recipientGuid, notification, CancellationToken.None);
            }
            catch (Exception ex)
            {
                log.LogWarning(ex, "Push for checkout failed.");
            }
        });
    }
}
