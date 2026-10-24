using System.Text.Json;
using AirFlash.Core;
using Xunit;
namespace AirFlash.Tests;

public sealed class EngineNoticeTests
{
    private const string Guidance = "The HomePod connection was interrupted. Check the HomePod and network, then reconnect.";

    [Fact]
    public void ActualControlWriteFailureIncludesActionAndAllRawDetails()
    {
        using var payload = JsonDocument.Parse("""{"event":"error","code":"write_failed","host":"receiver","channel":"feedback","message":"control write state is unusable","retryable":true}""");
        var notice = EngineNotice.Parse(payload.RootElement);
        Assert.Equal(Guidance + "\ncontrol write state is unusable · receiver · feedback · write_failed", notice.Detail);
        Assert.Equal("control write state is unusable", notice.Message);
        Assert.True(notice.Retryable);
    }

    [Theory]
    [InlineData("write_failed")]
    [InlineData("peer_closed")]
    [InlineData("connection_reset")]
    [InlineData("socket_error")]
    [InlineData("read_timeout")]
    [InlineData("feedback_timeout")]
    [InlineData("media_send_timeout")]
    public void KnownInterruptedLinkCodesGetGuidanceWithoutChangingRawFields(string code)
    {
        var notice = new EngineNotice(code, "receiver", "channel", "raw failure", true);
        Assert.Equal(Guidance + "\nraw failure · receiver · channel · " + code, notice.Detail);
        Assert.Equal(code, notice.Code); Assert.Equal("channel", notice.Channel); Assert.Equal("receiver", notice.Host);
    }

    [Theory]
    [InlineData("feedback_delayed")]
    [InlineData("media_send_delayed")]
    [InlineData("feedback_recovered")]
    [InlineData("media_send_recovered")]
    [InlineData("sender_late_recovered")]
    [InlineData("authentication_failed")]
    [InlineData("protocol_error")]
    [InlineData("engine_error")]
    [InlineData("unknown_error")]
    public void WarningsRecoveryAndUnrelatedErrorsKeepExistingDetails(string code)
    {
        var notice = new EngineNotice(code, "receiver", "channel", "raw message", true);
        Assert.Equal("raw message · receiver · channel · " + code, notice.Detail);
    }

    [Fact]
    public void ExplicitNonretryableFaultDoesNotSuggestReconnect()
    {
        var notice = new EngineNotice("write_failed", "receiver", "feedback", "permanent failure", false);
        Assert.Equal("permanent failure · receiver · feedback · write_failed", notice.Detail);
    }

    [Fact]
    public void LegacyRetryabilityStillGetsKnownLinkGuidance()
    {
        Assert.StartsWith(Guidance + "\n", new EngineNotice("peer_closed", "", "", "raw failure").Detail);
    }
}
