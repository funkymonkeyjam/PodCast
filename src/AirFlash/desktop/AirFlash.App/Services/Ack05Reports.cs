namespace AirFlash.App.Services;

// ACK05 vendor report decoding only. Battery reports and wheel movement never invoke transport.
internal sealed class Ack05Reports
{
    private HashSet<nint> _sources = [];
    private readonly Dictionary<nint, bool> _center = [];

    internal void SetSources(IEnumerable<nint> sources)
    {
        _sources = sources.ToHashSet();
        foreach (var removed in _center.Keys.Where(source => !_sources.Contains(source)).ToArray()) _center.Remove(removed);
    }

    internal void RemoveSource(nint source) { _sources.Remove(source); _center.Remove(source); }

    internal bool Read(nint source, ReadOnlySpan<byte> report)
    {
        if (!_sources.Contains(source) || report.Length < 8 || report[0] != 0x02 || report[1] != 0xF0) return false;
        var pressed = (report[3] & 0x04) != 0;
        _center.TryGetValue(source, out var previous);
        _center[source] = pressed;
        return pressed && !previous;
    }

    internal static bool IsDevicePath(string path) => path.Split('#').Any(part =>
    {
        var tokens = part.Split('&');
        return tokens.Contains("VID_28BD", StringComparer.OrdinalIgnoreCase) &&
            tokens.Contains("PID_0202", StringComparer.OrdinalIgnoreCase) &&
            tokens.Contains("MI_02", StringComparer.OrdinalIgnoreCase);
    });
}
