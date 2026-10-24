namespace AirFlash.Core;

public static class DedicatedCapture
{
    public static bool IsCableOutput(AudioEndpoint endpoint) => endpoint.Kind == AudioEndpointKind.Recording &&
        endpoint.Name.Equals("CABLE Output (VB-Audio Virtual Cable)", StringComparison.OrdinalIgnoreCase);

    public static AudioEndpoint Require(AppSettings settings, IReadOnlyList<AudioEndpoint> endpoints)
    {
        if (settings.CaptureMode != "endpoint" || string.IsNullOrWhiteSpace(settings.CaptureEndpoint))
            throw new InvalidOperationException("Select CABLE Output in Settings → Audio capture before connecting.");
        var endpoint = endpoints.SingleOrDefault(e => e.Id == settings.CaptureEndpoint);
        if (endpoint is null || !IsCableOutput(endpoint))
            throw new InvalidOperationException("The selected CABLE Output is unavailable or changed. Select it again in Settings → Audio capture.");
        return endpoint;
    }
}
