using System.Runtime.InteropServices;
using System.Windows.Interop;
namespace AirFlash.App.Services;

internal sealed class MediaHotkeyService : IDisposable
{
    private readonly HwndSource _source;
    private readonly MediaHotkeyRegistration _registration;
    private readonly Ack05Input? _ack05;
    private readonly Func<int, Task> _changeVolume;
    private readonly Action<Exception> _reportError;
    private readonly SpotifyPlayback _spotify = new();
    private readonly CancellationTokenSource _lifetime = new();
    private bool _disposed, _playPauseBusy;

    internal MediaHotkeyService(Func<int, Task> changeVolume, Action<Exception> reportError)
    {
        _changeVolume = changeVolume; _reportError = reportError;
        _source = new(new HwndSourceParameters("PodCast media controls") { ParentWindow = new nint(-3) });
        _source.AddHook(WindowMessage);
        try
        {
            _registration = new((id, modifiers, key) => RegisterHotKey(_source.Handle, id, modifiers, key),
                id => UnregisterHotKey(_source.Handle, id), Marshal.GetLastWin32Error);
        }
        catch { _source.RemoveHook(WindowMessage); _source.Dispose(); _lifetime.Dispose(); throw; }
        try { _ack05 = new(_source.Handle, () => _ = HandleAsync(MediaControlAction.PlayPause), AppPaths.Log); }
        catch (Exception error) { AppPaths.Log($"Optional ACK05 center input unavailable: {error.Message}"); }
    }

    private nint WindowMessage(nint hwnd, int message, nint wParam, nint lParam, ref bool handled)
    {
        if (_disposed) return 0;
        _ack05?.HandleMessage(message, wParam, lParam);
        if (message != 0x0312) return 0; // WM_HOTKEY
        var hotkey = MediaHotkeyRegistration.Keys.FirstOrDefault(key => key.Id == wParam.ToInt32());
        if (hotkey is null) return 0;
        handled = true;
        _ = HandleAsync(hotkey.Action);
        return 0;
    }

    private async Task HandleAsync(MediaControlAction action)
    {
        try
        {
            if (action == MediaControlAction.PlayPause)
            {
                if (_playPauseBusy) return;
                _playPauseBusy = true;
                try { await _spotify.ToggleAsync(_lifetime.Token); }
                finally { _playPauseBusy = false; }
            }
            else await _changeVolume(action == MediaControlAction.VolumeDown ? -3 : 3);
        }
        catch (OperationCanceledException) when (_disposed) { }
        catch (Exception error) { if (!_disposed) _reportError(error); }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true; _lifetime.Cancel();
        _ack05?.Dispose(); _registration.Dispose(); _source.RemoveHook(WindowMessage); _source.Dispose(); _lifetime.Dispose();
    }

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RegisterHotKey(nint hwnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnregisterHotKey(nint hwnd, int id);
}
