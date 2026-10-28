using System.ComponentModel;
using AirFlash.App.Services;
using AirFlash.Core;
using Xunit;
namespace AirFlash.Tests;

public class MediaControlTests
{
    [Theory]
    [InlineData("Spotify.exe")]
    [InlineData("SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify")]
    public void OnlyExactSpotifyIdentityIsEligible(string spotify)
    {
        Assert.Equal(spotify, MediaControlPolicy.SelectSpotify(new[] { "Teams.exe", "chrome.exe", spotify }, item => item));
        Assert.Throws<InvalidOperationException>(() => MediaControlPolicy.SelectSpotify(new[] { "SpotifyHelper.exe", "C:\\Spotify.exe", "MySpotify.exe", "Spotify.exe.fake" }, item => item));
        Assert.Throws<InvalidOperationException>(() => MediaControlPolicy.SelectSpotify(new[] { "Spotify.exe", "SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify" }, item => item));
    }

    private static SessionSnapshot Active(PlaybackState state = PlaybackState.Streaming, DeviceVolumeState? volume = null) =>
        new(state, new Receiver("office", "Office", "192.0.2.1"), DeviceVolume: volume ?? new(39, Available: true));

    [Theory]
    [InlineData(PlaybackState.Idle)]
    [InlineData(PlaybackState.Connecting)]
    [InlineData(PlaybackState.Pairing)]
    [InlineData(PlaybackState.Error)]
    public void VolumeRequiresActiveAvailableReceiver(PlaybackState state)
    {
        Assert.Null(MediaControlPolicy.ReceiverVolumeTarget(Active(state), 3));
        Assert.Null(MediaControlPolicy.ReceiverVolumeTarget(Active(volume: new(39, Available: false)), 3));
        Assert.Null(MediaControlPolicy.ReceiverVolumeTarget(Active(volume: new(Available: true)), 3));
        Assert.Null(MediaControlPolicy.ReceiverVolumeTarget(Active() with { Receiver = null }, 3));
    }

    [Fact]
    public void VolumeUsesPendingTargetAndClampsWithoutSystemFallback()
    {
        Assert.Equal(36, MediaControlPolicy.ReceiverVolumeTarget(Active(), -3));
        Assert.Equal(42, MediaControlPolicy.ReceiverVolumeTarget(Active(PlaybackState.Standby), 3));
        Assert.Equal(48, MediaControlPolicy.ReceiverVolumeTarget(Active(volume: new(39, 45, Available: true)), 3));
        Assert.Equal(100, MediaControlPolicy.ReceiverVolumeTarget(Active(volume: new(99, Available: true)), 3));
        Assert.Equal(0, MediaControlPolicy.ReceiverVolumeTarget(Active(volume: new(1, Available: true)), -3));
    }

    [Fact]
    public void RegistrationConflictReleasesEarlierKeysAndNamesShortcut()
    {
        var registered = new List<int>(); var removed = new List<int>();
        var error = Assert.Throws<Win32Exception>(() => new MediaHotkeyRegistration((id, modifiers, key) =>
        {
            Assert.Equal(0x4003u, modifiers);
            registered.Add(id); return registered.Count < 2;
        }, removed.Add, () => 1409));
        Assert.Contains("Ctrl+Alt+F10", error.Message);
        Assert.Equal(1409, error.NativeErrorCode);
        Assert.Equal(new[] { registered[0] }, removed);
    }

    [Fact]
    public void DisposalReleasesEveryKeyOnlyOnce()
    {
        var removed = new List<int>();
        var registration = new MediaHotkeyRegistration((_, _, _) => true, removed.Add, () => 0);
        registration.Dispose(); registration.Dispose();
        Assert.Equal(MediaHotkeyRegistration.Keys.Select(key => key.Id), removed);
        Assert.Equal(new uint[] { 0x78, 0x79, 0x7A }, MediaHotkeyRegistration.Keys.Select(key => key.Key));
    }
}
