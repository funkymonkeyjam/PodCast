using AirFlash.Core;
using Xunit;
namespace AirFlash.Tests;

public sealed class DedicatedCaptureTests
{
    [Theory]
    [InlineData("loopback", "cable")]
    [InlineData("endpoint", null)]
    [InlineData("endpoint", "")]
    [InlineData("endpoint", "missing")]
    [InlineData("endpoint", "CABLE Output (VB-Audio Virtual Cable)")]
    public void MissingOrImplicitSourceNeverSelectsAnotherEndpoint(string mode, string? id)
    {
        var settings = new AppSettings { CaptureMode = mode, CaptureEndpoint = id };
        Assert.Throws<InvalidOperationException>(() => DedicatedCapture.Require(settings,
            [new("cable", "CABLE Output (VB-Audio Virtual Cable)", AudioEndpointKind.Recording)]));
    }

    [Theory]
    [InlineData("Microphone", AudioEndpointKind.Recording)]
    [InlineData("Stereo Mix", AudioEndpointKind.Recording)]
    [InlineData("CABLE Output (other)", AudioEndpointKind.Recording)]
    [InlineData("CABLE Output (VB-Audio Virtual Cable)", AudioEndpointKind.Playback)]
    public void ChangedOrWrongDeviceIsRejected(string name, AudioEndpointKind kind)
    {
        Assert.Throws<InvalidOperationException>(() => DedicatedCapture.Require(new() { CaptureEndpoint = "selected" },
            [new("selected", name, kind)]));
    }

    [Fact]
    public void StableRecordingIdentityIsPreserved()
    {
        var selected = new AudioEndpoint("stable", "CABLE Output (VB-Audio Virtual Cable)", AudioEndpointKind.Recording);
        Assert.Same(selected, DedicatedCapture.Require(new() { CaptureEndpoint = "stable" }, [selected]));
    }

    [Fact]
    public async Task IpcLineLimitIsEnforcedBeforeReadingAnUnboundedEvent()
    {
        using var reader = new StringReader(new string('x', 65537));
        await Assert.ThrowsAsync<IOException>(() => ProcessEngineConnection.ReadBoundedLineAsync(reader, CancellationToken.None));
    }

    [Fact]
    public async Task BoundedIpcReaderPreservesLinesEofAndCancellation()
    {
        using var reader = new StringReader("first\r\nsecond");
        Assert.Equal("first", await ProcessEngineConnection.ReadBoundedLineAsync(reader, CancellationToken.None));
        Assert.Equal("second", await ProcessEngineConnection.ReadBoundedLineAsync(reader, CancellationToken.None));
        Assert.Null(await ProcessEngineConnection.ReadBoundedLineAsync(reader, CancellationToken.None));
        using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => ProcessEngineConnection.ReadBoundedLineAsync(reader, cancelled.Token));
    }
}
