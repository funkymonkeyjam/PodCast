using Windows.Media.Control;
namespace AirFlash.App.Services;

internal sealed class SpotifyPlayback
{
    internal async Task ToggleAsync(CancellationToken cancellation)
    {
        cancellation.ThrowIfCancellationRequested();
        var manager = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync().AsTask(cancellation);
        var session = MediaControlPolicy.SelectSpotify(manager.GetSessions(), item => item.SourceAppUserModelId)!;
        cancellation.ThrowIfCancellationRequested();
        if (!await session.TryTogglePlayPauseAsync().AsTask(cancellation))
            throw new InvalidOperationException("Spotify did not accept play/pause. Open Spotify and select a song, then try again.");
    }
}
