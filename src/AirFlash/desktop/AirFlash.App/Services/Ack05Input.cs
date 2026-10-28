using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
namespace AirFlash.App.Services;

// Passive RawInput subscription: no HID handles/writes, legacy suppression or synthesized keys.
internal sealed class Ack05Input : IDisposable
{
    private readonly Ack05Reports _reports = new();
    private readonly Action _centerPressed;
    private readonly Action<string> _log;
    private bool _disposed;
    private const ushort UsagePage = 0xFF0A, Usage = 0x0001;

    internal Ack05Input(nint target, Action centerPressed, Action<string> log)
    {
        _centerPressed = centerPressed; _log = log;
        RefreshSources();
        var registration = new RawInputDevice { UsagePage = UsagePage, Usage = Usage, Flags = 0x0100 | 0x2000, Target = target };
        if (!RegisterRawInputDevices([registration], 1, (uint)Marshal.SizeOf<RawInputDevice>()))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "ACK05 center-button RawInput registration failed. Reconnect the ACK05 and restart PodCast. Keyboard Spotify controls remain available.");
    }

    internal void HandleMessage(int message, nint eventKind, nint input)
    {
        if (_disposed) return;
        try
        {
            if (message == 0x00FE) // WM_INPUT_DEVICE_CHANGE
            {
                if (eventKind == 2) _reports.RemoveSource(input); // GIDC_REMOVAL
                RefreshSources();
            }
            else if (message == 0x00FF) ReadInput(input); // WM_INPUT; caller leaves default processing enabled.
        }
        catch (Exception error)
        {
            if (message == 0x00FE) _reports.SetSources([]); // Never retain uncertain device identities.
            _log($"ACK05 passive input failed: {error.Message}");
        }
    }

    private void RefreshSources()
    {
        uint count = 0;
        var entrySize = (uint)Marshal.SizeOf<RawInputDeviceList>();
        if (GetRawInputDeviceList(null, ref count, entrySize) == uint.MaxValue) throw NativeError("RawInput enumeration failed");
        var entries = new RawInputDeviceList[count];
        var found = GetRawInputDeviceList(entries, ref count, entrySize);
        if (found == uint.MaxValue) throw NativeError("RawInput enumeration failed");
        var sources = new List<nint>();
        for (var i = 0; i < found; i++)
        {
            if (entries[i].Type != 2) continue;
            uint length = 0;
            if (GetDeviceName(entries[i].Device, 0x20000007, null, ref length) == uint.MaxValue) continue;
            var path = new StringBuilder((int)length + 1);
            if (GetDeviceName(entries[i].Device, 0x20000007, path, ref length) == uint.MaxValue || !Ack05Reports.IsDevicePath(path.ToString())) continue;
            var info = new DeviceInfo { Size = (uint)Marshal.SizeOf<DeviceInfo>() };
            var infoSize = info.Size;
            if (GetDeviceInfo(entries[i].Device, 0x2000000B, ref info, ref infoSize) == uint.MaxValue) continue;
            if (info.Type == 2 && info.VendorId == 0x28BD && info.ProductId == 0x0202 && info.UsagePage == UsagePage && info.Usage == Usage)
                sources.Add(entries[i].Device);
        }
        _reports.SetSources(sources);
        _log($"ACK05 passive center input sources={sources.Count}.");
    }

    private void ReadInput(nint input)
    {
        uint size = 0;
        var headerSize = (uint)Marshal.SizeOf<RawInputHeader>();
        if (GetRawInputData(input, 0x10000003, 0, ref size, headerSize) == uint.MaxValue) throw NativeError("RawInput size query failed");
        if (size < headerSize + 8 || size > 65536) return;
        var capacity = size;
        var data = Marshal.AllocHGlobal((int)capacity);
        try
        {
            var read = GetRawInputData(input, 0x10000003, data, ref size, headerSize);
            if (read == uint.MaxValue) throw NativeError("RawInput read failed");
            if (read < headerSize + 8 || read > capacity) return;
            var header = Marshal.PtrToStructure<RawInputHeader>(data);
            if (header.Type != 2) return;
            var reportSize = Marshal.ReadInt32(data, (int)headerSize);
            var reportCount = Marshal.ReadInt32(data, (int)headerSize + 4);
            if (reportSize <= 0 || reportCount <= 0 || (long)reportSize * reportCount > read - headerSize - 8) return;
            var report = new byte[reportSize];
            for (var i = 0; i < reportCount; i++)
            {
                Marshal.Copy(nint.Add(data, (int)headerSize + 8 + i * reportSize), report, 0, reportSize);
                if (_reports.Read(header.Device, report))
                {
                    _log("ACK05 center-button press recognized; requesting Spotify play/pause.");
                    _centerPressed();
                }
            }
        }
        finally { Marshal.FreeHGlobal(data); }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        var remove = new RawInputDevice { UsagePage = UsagePage, Usage = Usage, Flags = 0x0001, Target = 0 };
        if (!RegisterRawInputDevices([remove], 1, (uint)Marshal.SizeOf<RawInputDevice>()))
            _log($"ACK05 passive input unregister failed: {Marshal.GetLastWin32Error()}");
        _reports.SetSources([]);
    }

    private static Win32Exception NativeError(string message) => new(Marshal.GetLastWin32Error(), message);
    [StructLayout(LayoutKind.Sequential)]
    private struct RawInputDeviceList { internal nint Device; internal uint Type; }
    [StructLayout(LayoutKind.Sequential)]
    private struct RawInputDevice { internal ushort UsagePage, Usage; internal uint Flags; internal nint Target; }
    [StructLayout(LayoutKind.Sequential)]
    private struct RawInputHeader { internal uint Type, Size; internal nint Device, WParam; }
    [StructLayout(LayoutKind.Explicit, Size = 32)]
    private struct DeviceInfo
    {
        [FieldOffset(0)] internal uint Size;
        [FieldOffset(4)] internal uint Type;
        [FieldOffset(8)] internal uint VendorId;
        [FieldOffset(12)] internal uint ProductId;
        [FieldOffset(20)] internal ushort UsagePage;
        [FieldOffset(22)] internal ushort Usage;
    }
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetRawInputDeviceList([Out] RawInputDeviceList[]? devices, ref uint count, uint size);
    [DllImport("user32.dll", EntryPoint = "GetRawInputDeviceInfoW", SetLastError = true)]
    private static extern uint GetDeviceInfo(nint device, uint command, ref DeviceInfo info, ref uint size);
    [DllImport("user32.dll", EntryPoint = "GetRawInputDeviceInfoW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetDeviceName(nint device, uint command, StringBuilder? name, ref uint size);
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool RegisterRawInputDevices([In] RawInputDevice[] devices, uint count, uint size);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetRawInputData(nint input, uint command, nint data, ref uint size, uint headerSize);
}
