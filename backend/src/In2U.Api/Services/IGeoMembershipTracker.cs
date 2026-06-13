namespace In2U.Api.Services;

public interface IGeoMembershipTracker
{
    void AddConnection(Guid userGuid, string connectionId);
    void RemoveConnection(Guid userGuid, string connectionId);
    bool IsConnected(Guid userGuid);
    IReadOnlyCollection<string> GetConnections(Guid userGuid);
    int GetConnectedUserCount();

    // App-state (foreground/background). Unknown user => background.
    void SetAppState(Guid userGuid, bool isForeground);
    bool IsForeground(Guid userGuid);

    // Push delivery rule: push when user is not connected OR not in foreground.
    bool ShouldPush(Guid userGuid);
}
