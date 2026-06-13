using System.Collections.Concurrent;

namespace In2U.Api.Services;

public sealed class GeoMembershipTracker : IGeoMembershipTracker
{
    private readonly ConcurrentDictionary<Guid, HashSet<string>> _connections = new();
    private readonly ConcurrentDictionary<Guid, bool> _appState = new();

    public void AddConnection(Guid userGuid, string connectionId)
    {
        var set = _connections.GetOrAdd(userGuid, _ => new HashSet<string>());
        lock (set)
        {
            set.Add(connectionId);
        }
    }

    public void RemoveConnection(Guid userGuid, string connectionId)
    {
        if (!_connections.TryGetValue(userGuid, out var set)) return;
        var removed = false;
        lock (set)
        {
            set.Remove(connectionId);
            if (set.Count == 0)
            {
                _connections.TryRemove(userGuid, out _);
                removed = true;
            }
        }
        if (removed)
        {
            // No remaining connections => implicit "background/offline".
            _appState.TryRemove(userGuid, out _);
        }
    }

    public bool IsConnected(Guid userGuid)
    {
        if (!_connections.TryGetValue(userGuid, out var set)) return false;
        lock (set)
        {
            return set.Count > 0;
        }
    }

    public IReadOnlyCollection<string> GetConnections(Guid userGuid)
    {
        if (!_connections.TryGetValue(userGuid, out var set)) return Array.Empty<string>();
        lock (set)
        {
            return set.ToArray();
        }
    }

    public int GetConnectedUserCount() => _connections.Count;

    public void SetAppState(Guid userGuid, bool isForeground) =>
        _appState[userGuid] = isForeground;

    public bool IsForeground(Guid userGuid) =>
        _appState.TryGetValue(userGuid, out var v) && v;

    public bool ShouldPush(Guid userGuid) =>
        !IsConnected(userGuid) || !IsForeground(userGuid);
}
