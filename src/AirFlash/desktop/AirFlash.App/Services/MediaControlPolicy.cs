using AirFlash.Core;
namespace AirFlash.App.Services;

internal static class MediaControlPolicy
{
    internal static bool IsSpotify(string identity) =>
        string.Equals(identity, "SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify", StringComparison.OrdinalIgnoreCase) ||
        string.Equals(identity, "Spotify.exe", StringComparison.OrdinalIgnoreCase);

    internal static T? SelectSpotify<T>(IEnumerable<T> sessions, Func<T, string> identity) where T : class
    {
        var matches = sessions.Where(session => IsSpotify(identity(session))).Take(2).ToArray();
        return matches.Length switch
        {
            0 => throw new InvalidOperationException("Spotify has no media session. Open Spotify and start a song, then try again."),
            1 => matches[0],
            _ => throw new InvalidOperationException("More than one Spotify media session is available. Close the extra Spotify instance, then try again.")
        };
    }

    internal static int? ReceiverVolumeTarget(SessionSnapshot snapshot, int change)
    {
        if (snapshot.State is not (PlaybackState.Streaming or PlaybackState.Standby) ||
            snapshot.Receiver is null || snapshot.DeviceVolume is not { Available: true, Display: int current }) return null;
        return (int)Math.Clamp((long)current + change, 0, 100);
    }
}
