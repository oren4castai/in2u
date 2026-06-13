namespace In2U.Api.Common;

public sealed record PushNotification(
    string Title,
    string Body,
    IReadOnlyDictionary<string, string> Data,
    string? Sound = "default",
    bool HighPriority = true);
