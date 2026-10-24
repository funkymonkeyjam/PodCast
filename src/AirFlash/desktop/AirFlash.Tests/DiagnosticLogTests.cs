using AirFlash.Core;
using Xunit;
namespace AirFlash.Tests;

public sealed class DiagnosticLogTests
{
    [Fact]
    public void RepeatedRotationRetainsTwoFilesWithinByteLimit()
    {
        InDirectory(directory =>
        {
            for (var i = 0; i < 100; i++) DiagnosticLog.Write(directory, i + new string('界', 8192));
            var files = Directory.GetFiles(directory);
            Assert.Equal(2, files.Length);
            Assert.All(files, file => Assert.InRange(new FileInfo(file).Length, 1, DiagnosticLog.MaxFileBytes));
            Assert.Contains("99", File.ReadAllText(Path.Combine(directory, "wpf.log")));
        });
    }

    [Fact]
    public void OversizedEntryIsTruncatedAfterCredentialAndPathRedaction()
    {
        InDirectory(directory =>
        {
            DiagnosticLog.Write(directory, "pin=123456 password=\"secret value\" private_key=abc " +
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + new string('x', 50000));
            var log = File.ReadAllText(Path.Combine(directory, "wpf.log"));
            Assert.DoesNotContain("123456", log); Assert.DoesNotContain("secret value", log); Assert.DoesNotContain("abc", log);
            Assert.Contains("[redacted]", log); Assert.Contains("[user-path]", log); Assert.Contains("[truncated]", log);
            Assert.InRange(new FileInfo(Path.Combine(directory, "wpf.log")).Length, 1, DiagnosticLog.MaxFileBytes);
        });
    }

    [Fact]
    public void PreexistingOversizedCurrentFileCannotBreakTheCap()
    {
        InDirectory(directory =>
        {
            File.WriteAllText(Path.Combine(directory, "wpf.log"), new string('x', DiagnosticLog.MaxFileBytes + 1));
            DiagnosticLog.Write(directory, "engine restarted");
            Assert.Single(Directory.GetFiles(directory));
            Assert.Contains("engine restarted", File.ReadAllText(Path.Combine(directory, "wpf.log")));
        });
    }

    private static void InDirectory(Action<string> action)
    {
        var directory = Path.Combine(Path.GetTempPath(), "PodCast-log-tests-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try { action(directory); }
        finally { Directory.Delete(directory, true); }
    }
}
