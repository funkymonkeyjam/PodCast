using AirFlash.App.Services;
using Xunit;
namespace AirFlash.Tests;

public class Ack05ReportsTests
{
    private static byte[] Frame(byte center = 0, byte wheel = 0) => [0x02, 0xF0, 0, center, 0, 0, 0, wheel];
    private static Ack05Reports Reader() { var reader = new Ack05Reports(); reader.SetSources([1, 2]); return reader; }

    [Fact]
    public void CenterFiresOncePerPressAndTracksEachDeviceSeparately()
    {
        var reader = Reader();
        Assert.True(reader.Read(1, Frame(4)));
        Assert.False(reader.Read(1, Frame(4)));
        Assert.True(reader.Read(2, Frame(4)));
        Assert.False(reader.Read(1, Frame()));
        Assert.True(reader.Read(1, Frame(4)));
    }

    [Fact]
    public void UnrelatedSourcesFramesBatteryAndWheelAreIgnored()
    {
        var reader = Reader();
        Assert.False(reader.Read(3, Frame(4)));
        Assert.False(reader.Read(1, [0x02, 0xF0, 0, 4]));
        Assert.False(reader.Read(1, [0x02, 0xF2, 0, 4, 0, 0, 0, 0]));
        Assert.False(reader.Read(1, [0x03, 0xF0, 0, 4, 0, 0, 0, 0]));
        Assert.False(reader.Read(1, Frame(wheel: 1)));
        Assert.False(reader.Read(1, Frame(wheel: 2)));
        Assert.True(reader.Read(1, Frame(4)));
        Assert.False(reader.Read(1, [0x02, 0xF2, 0, 0, 0, 0, 0, 0]));
        Assert.False(reader.Read(1, Frame(4)));
    }

    [Fact]
    public void RemovalDiscardsSourceAndItsHeldState()
    {
        var reader = Reader();
        Assert.True(reader.Read(1, Frame(4)));
        reader.SetSources([2]);
        Assert.False(reader.Read(1, Frame(4)));
        reader.SetSources([1, 2]);
        Assert.True(reader.Read(1, Frame(4)));
    }

    [Theory]
    [InlineData(@"\\?\HID#VID_28BD&PID_0202&MI_02&Col01#device", true)]
    [InlineData(@"\\?\hid#vid_28bd&pid_0202&mi_02#device", true)]
    [InlineData(@"\\?\HID#VID_28BD&PID_0202&MI_020#device", false)]
    [InlineData(@"\\?\HID#VID_28BD&PID_02020&MI_02#device", false)]
    [InlineData(@"\\?\HID#VID_0000&PID_0202&MI_02#device", false)]
    public void DevicePathRequiresExactVendorProductAndInterface(string path, bool matches) =>
        Assert.Equal(matches, Ack05Reports.IsDevicePath(path));
}
