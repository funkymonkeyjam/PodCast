using System.Diagnostics;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Security.Principal;
using Microsoft.Win32.SafeHandles;
namespace AirFlash.App.Services;

public sealed class SingleInstance : IAsyncDisposable
{
    private readonly Mutex _mutex;
    private readonly string _pipeName;
    private readonly CancellationTokenSource _stop = new();
    private Task? _server;
    public bool IsOwner { get; }
    public SingleInstance(string? isolatedSuffix = null)
    {
        var suffix = WindowsIdentity.GetCurrent().User?.Value ?? Environment.UserName;
        _pipeName = "PodCast.Wpf." + suffix + (isolatedSuffix is null ? "" : "." + isolatedSuffix);
        _mutex = new(true, @"Local\" + _pipeName, out var created);
        IsOwner = created;
    }
    public async Task NotifyExistingAsync()
    {
        using var stop = new CancellationTokenSource(TimeSpan.FromSeconds(3));
        using var pipe = new NamedPipeClientStream(".", _pipeName, PipeDirection.Out, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
        await pipe.ConnectAsync(stop.Token); await pipe.WriteAsync(new byte[] { 1 }, stop.Token); await pipe.FlushAsync(stop.Token);
    }
    public async Task<bool> RequestQuitAsync()
    {
        using var stop = new CancellationTokenSource(TimeSpan.FromSeconds(30));
        try
        {
            using var pipe = new NamedPipeClientStream(".", _pipeName, PipeDirection.Out, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
            await pipe.ConnectAsync(stop.Token);
            if (!GetNamedPipeServerProcessId(pipe.SafePipeHandle, out var processId) || processId == Environment.ProcessId) return false;
            using var owner = Process.GetProcessById(checked((int)processId));
            var ownerPath = owner.MainModule?.FileName;
            if (string.IsNullOrEmpty(ownerPath) || string.IsNullOrEmpty(Environment.ProcessPath)
                || !string.Equals(ownerPath, Environment.ProcessPath, StringComparison.OrdinalIgnoreCase)) return false;
            await pipe.WriteAsync(new byte[] { 2 }, stop.Token); await pipe.FlushAsync(stop.Token);
            pipe.Dispose();
            await owner.WaitForExitAsync(stop.Token);
            return true;
        }
        catch (Exception error) when (error is OperationCanceledException or IOException or System.ComponentModel.Win32Exception or ArgumentException or InvalidOperationException)
        {
            AppPaths.Log($"Graceful quit request failed: {error.Message}");
            return false;
        }
    }
    public void Listen(Action activate, Action? quit = null) => _server = Task.Run(async () =>
    {
        try
        {
            while (!_stop.IsCancellationRequested)
            {
                await using var pipe = new NamedPipeServerStream(_pipeName, PipeDirection.In, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly);
                await pipe.WaitForConnectionAsync(_stop.Token);
                var input = new byte[1];
                if (await pipe.ReadAsync(input, _stop.Token) == 1)
                {
                    if (input[0] == 1) activate();
                    else if (input[0] == 2) quit?.Invoke();
                }
            }
        }
        catch (OperationCanceledException) when (_stop.IsCancellationRequested) { }
        catch (IOException error) { AppPaths.Log(error.ToString()); }
    });
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetNamedPipeServerProcessId(SafePipeHandle pipe, out uint serverProcessId);
    public async ValueTask DisposeAsync()
    {
        await _stop.CancelAsync(); if (_server is not null) await _server;
        if (IsOwner) _mutex.ReleaseMutex(); _mutex.Dispose(); _stop.Dispose();
    }
}
