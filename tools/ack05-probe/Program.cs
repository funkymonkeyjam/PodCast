using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

// Passive diagnostic only: no HID handles, output reports, key injection or driver changes.
internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        bool listOnly = false;
        int seconds = 30;
        for (int i = 0; i < args.Length; i++)
        {
            if (args[i] == "--list") listOnly = true;
            else if (args[i] == "--seconds" && i + 1 < args.Length &&
                     int.TryParse(args[++i], out seconds) && seconds >= 1 && seconds <= 3600) { }
            else
            {
                Console.Error.WriteLine("Usage: ack05-probe.exe [--list] [--seconds 1..3600]");
                return 1;
            }
        }

        try
        {
            List<Device> devices = Native.FindDevices();
            if (devices.Count == 0)
            {
                Console.Error.WriteLine("ABSENT: no RawInput vendor HID collection for VID_28BD PID_0202 MI_02. No listener registered.");
                return 2;
            }
            foreach (Device device in devices)
                Console.WriteLine("DEVICE handle=0x{0:X} usagePage=0x{1:X4} usage=0x{2:X4} path={3}",
                    device.Handle.ToInt64(), device.UsagePage, device.Usage, device.Path);
            if (listOnly) return 0;

            using (Probe probe = new Probe(devices, seconds)) Application.Run(probe);
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("ERROR: " + error.Message);
            return 3;
        }
    }
}

internal sealed class Device
{
    internal IntPtr Handle;
    internal ushort UsagePage;
    internal ushort Usage;
    internal string Path;
}

internal sealed class Probe : ApplicationContext
{
    private readonly InputWindow window;
    private readonly Timer timer;
    private readonly List<Native.RawInputDevice> registrations = new List<Native.RawInputDevice>();

    internal Probe(List<Device> devices, int seconds)
    {
        window = new InputWindow(devices);
        try
        {
            HashSet<uint> collections = new HashSet<uint>();
            foreach (Device device in devices)
            {
                uint key = ((uint)device.UsagePage << 16) | device.Usage;
                if (!collections.Add(key)) continue;
                Native.RawInputDevice registration = new Native.RawInputDevice();
                registration.UsagePage = device.UsagePage;
                registration.Usage = device.Usage;
                registration.Flags = 0x00000100; // RIDEV_INPUTSINK; legacy input remains enabled.
                registration.Target = window.Handle;
                if (!Native.RegisterRawInputDevices(new[] { registration }, 1,
                        (uint)Marshal.SizeOf(typeof(Native.RawInputDevice))))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "RawInput registration failed");
                registrations.Add(registration);
            }
            Console.WriteLine("LISTENING seconds={0}; exact source handles only; no input suppression or HID writes.", seconds);
            timer = new Timer();
            timer.Interval = seconds * 1000;
            timer.Tick += delegate { ExitThread(); };
            timer.Start();
        }
        catch
        {
            RemoveRegistrations();
            window.DestroyHandle();
            throw;
        }
    }

    protected override void ExitThreadCore()
    {
        timer.Stop();
        Console.WriteLine("FINISHED matchingReports={0} centerPresses={1} wheelSteps={2}",
            window.ReportCount, window.CenterCount, window.WheelCount);
        if (window.ReportCount == 0)
            Console.WriteLine("NO_REPORTS: registration succeeded but no reports arrived from the exact ACK05 source. Center visibility is unverified.");
        base.ExitThreadCore();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            if (timer != null) timer.Dispose();
            RemoveRegistrations();
            window.DestroyHandle();
        }
        base.Dispose(disposing);
    }

    private void RemoveRegistrations()
    {
        foreach (Native.RawInputDevice previous in registrations)
        {
            Native.RawInputDevice remove = previous;
            remove.Flags = 0x00000001; // RIDEV_REMOVE requires a null target.
            remove.Target = IntPtr.Zero;
            if (!Native.RegisterRawInputDevices(new[] { remove }, 1,
                    (uint)Marshal.SizeOf(typeof(Native.RawInputDevice))))
                Console.Error.WriteLine("WARNING: unregister failed: " + Marshal.GetLastWin32Error());
        }
        registrations.Clear();
    }
}

internal sealed class InputWindow : NativeWindow
{
    private readonly HashSet<IntPtr> sources = new HashSet<IntPtr>();
    private readonly Dictionary<IntPtr, bool> centerStates = new Dictionary<IntPtr, bool>();
    internal long ReportCount;
    internal long CenterCount;
    internal long WheelCount;

    internal InputWindow(List<Device> devices)
    {
        foreach (Device device in devices) sources.Add(device.Handle);
        CreateParams parameters = new CreateParams();
        parameters.Caption = "ACK05 passive diagnostic";
        parameters.Parent = new IntPtr(-3); // Message-only window, never shown or focused.
        CreateHandle(parameters);
    }

    protected override void WndProc(ref Message message)
    {
        if (message.Msg == 0x00FF)
        {
            try { ReadInput(message.LParam); }
            catch (Exception error) { Console.Error.WriteLine("READ_ERROR: " + error.Message); }
        }
        base.WndProc(ref message);
    }

    private void ReadInput(IntPtr input)
    {
        uint size = 0;
        uint headerSize = (uint)Marshal.SizeOf(typeof(Native.RawInputHeader));
        if (Native.GetRawInputData(input, 0x10000003, IntPtr.Zero, ref size, headerSize) == uint.MaxValue)
            throw new Win32Exception(Marshal.GetLastWin32Error());
        if (size < headerSize + 8 || size > 65536) return;
        IntPtr data = Marshal.AllocHGlobal((int)size);
        try
        {
            uint read = Native.GetRawInputData(input, 0x10000003, data, ref size, headerSize);
            if (read == uint.MaxValue) throw new Win32Exception(Marshal.GetLastWin32Error());
            if (read < headerSize + 8) return;
            Native.RawInputHeader header = (Native.RawInputHeader)Marshal.PtrToStructure(data, typeof(Native.RawInputHeader));
            if (header.Type != 2 || !sources.Contains(header.Device)) return;
            int reportSize = Marshal.ReadInt32(data, (int)headerSize);
            int count = Marshal.ReadInt32(data, (int)headerSize + 4);
            if (reportSize <= 0 || count <= 0 || (long)reportSize * count > read - headerSize - 8) return;
            byte[] report = new byte[reportSize];
            for (int i = 0; i < count; i++)
            {
                Marshal.Copy(IntPtr.Add(data, (int)headerSize + 8 + i * reportSize), report, 0, reportSize);
                ProcessReport(header.Device, report);
            }
        }
        finally { Marshal.FreeHGlobal(data); }
    }

    private void ProcessReport(IntPtr source, byte[] report)
    {
        ReportCount++;
        bool recognized = report.Length >= 8 && report[0] == 0x02 && report[1] == 0xF0;
        string decoded = "unrecognized";
        if (recognized)
        {
            bool pressed = (report[3] & 0x04) != 0;
            bool previous;
            centerStates.TryGetValue(source, out previous);
            bool rising = pressed && !previous;
            centerStates[source] = pressed;
            if (rising) CenterCount++;
            string wheel = report[7] == 1 ? "cw" : report[7] == 2 ? "ccw" : "none";
            if (wheel != "none") WheelCount++;
            decoded = "center=" + (pressed ? "down" : "up") + " rising=" + rising + " wheel=" + wheel;
            if (rising) Console.WriteLine("CENTER_PRESS count=" + CenterCount);
        }
        // Keep diagnostics bounded even if the device streams heartbeat reports continuously.
        if (ReportCount <= 1000)
            Console.WriteLine("REPORT source=0x{0:X} bytes={1} raw={2} {3}", source.ToInt64(), report.Length,
                BitConverter.ToString(report, 0, Math.Min(64, report.Length)), decoded);
        else if (ReportCount == 1001) Console.WriteLine("REPORT_LIMIT: raw report output capped at 1000; center events and final counts continue.");
    }
}

internal static class Native
{
    [StructLayout(LayoutKind.Sequential)]
    internal struct RawInputDeviceList { internal IntPtr Device; internal uint Type; }
    [StructLayout(LayoutKind.Sequential)]
    internal struct RawInputDevice { internal ushort UsagePage, Usage; internal uint Flags; internal IntPtr Target; }
    [StructLayout(LayoutKind.Sequential)]
    internal struct RawInputHeader { internal uint Type, Size; internal IntPtr Device, WParam; }
    [StructLayout(LayoutKind.Explicit, Size = 32)]
    internal struct DeviceInfo
    {
        [FieldOffset(0)] internal uint Size;
        [FieldOffset(4)] internal uint Type;
        [FieldOffset(8)] internal uint VendorId;
        [FieldOffset(12)] internal uint ProductId;
        [FieldOffset(20)] internal ushort UsagePage;
        [FieldOffset(22)] internal ushort Usage;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetRawInputDeviceList([Out] RawInputDeviceList[] devices, ref uint count, uint size);
    [DllImport("user32.dll", EntryPoint = "GetRawInputDeviceInfoW", SetLastError = true)]
    private static extern uint GetDeviceInfo(IntPtr device, uint command, ref DeviceInfo info, ref uint size);
    [DllImport("user32.dll", EntryPoint = "GetRawInputDeviceInfoW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetDeviceName(IntPtr device, uint command, StringBuilder name, ref uint size);
    [DllImport("user32.dll", SetLastError = true)]
    internal static extern bool RegisterRawInputDevices([In] RawInputDevice[] devices, uint count, uint size);
    [DllImport("user32.dll", SetLastError = true)]
    internal static extern uint GetRawInputData(IntPtr input, uint command, IntPtr data, ref uint size, uint headerSize);

    internal static List<Device> FindDevices()
    {
        uint count = 0;
        uint entrySize = (uint)Marshal.SizeOf(typeof(RawInputDeviceList));
        if (GetRawInputDeviceList(null, ref count, entrySize) == uint.MaxValue)
            throw new Win32Exception(Marshal.GetLastWin32Error(), "RawInput enumeration failed");
        RawInputDeviceList[] entries = new RawInputDeviceList[count];
        uint found = GetRawInputDeviceList(entries, ref count, entrySize);
        if (found == uint.MaxValue) throw new Win32Exception(Marshal.GetLastWin32Error(), "RawInput enumeration failed");
        List<Device> result = new List<Device>();
        for (int i = 0; i < found; i++)
        {
            if (entries[i].Type != 2) continue;
            uint length = 0;
            if (GetDeviceName(entries[i].Device, 0x20000007, null, ref length) == uint.MaxValue) continue;
            StringBuilder name = new StringBuilder((int)length + 1);
            if (GetDeviceName(entries[i].Device, 0x20000007, name, ref length) == uint.MaxValue) continue;
            string path = name.ToString();
            if (path.IndexOf("vid_28bd&pid_0202&mi_02", StringComparison.OrdinalIgnoreCase) < 0) continue;
            DeviceInfo info = new DeviceInfo();
            info.Size = (uint)Marshal.SizeOf(typeof(DeviceInfo));
            uint infoSize = info.Size;
            if (GetDeviceInfo(entries[i].Device, 0x2000000B, ref info, ref infoSize) == uint.MaxValue)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "ACK05 device information failed");
            if (info.Type != 2 || info.VendorId != 0x28BD || info.ProductId != 0x0202 || info.UsagePage < 0xFF00) continue;
            result.Add(new Device { Handle = entries[i].Device, UsagePage = info.UsagePage, Usage = info.Usage, Path = path });
        }
        return result;
    }
}
