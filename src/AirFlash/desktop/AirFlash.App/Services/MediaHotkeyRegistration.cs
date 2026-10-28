using System.ComponentModel;
namespace AirFlash.App.Services;

internal enum MediaControlAction { PlayPause, VolumeDown, VolumeUp }
internal sealed record MediaHotkey(int Id, uint Key, MediaControlAction Action, string Shortcut);

// Owns registrations independently of the visible panel, which can be recreated for a language change.
internal sealed class MediaHotkeyRegistration : IDisposable
{
    internal const uint Modifiers = 0x0001 | 0x0002 | 0x4000; // Alt, Ctrl, no repeat
    internal static IReadOnlyList<MediaHotkey> Keys { get; } =
    [
        new(0x5041, 0x78, MediaControlAction.PlayPause, "Ctrl+Alt+F9"),
        new(0x5042, 0x79, MediaControlAction.VolumeDown, "Ctrl+Alt+F10"),
        new(0x5043, 0x7A, MediaControlAction.VolumeUp, "Ctrl+Alt+F11")
    ];
    private readonly Action<int> _unregister;
    private readonly List<int> _registered = [];

    internal MediaHotkeyRegistration(Func<int, uint, uint, bool> register, Action<int> unregister, Func<int> lastError)
    {
        _unregister = unregister;
        try
        {
            foreach (var key in Keys)
            {
                if (!register(key.Id, Modifiers, key.Key))
                    throw new Win32Exception(lastError(), $"PodCast could not register {key.Shortcut}. Close or change the shortcut in the other app using it, then restart PodCast. Spotify dial controls are unavailable; audio streaming can continue.");
                _registered.Add(key.Id);
            }
        }
        catch { Dispose(); throw; }
    }

    public void Dispose()
    {
        foreach (var id in _registered) _unregister(id);
        _registered.Clear();
    }
}
