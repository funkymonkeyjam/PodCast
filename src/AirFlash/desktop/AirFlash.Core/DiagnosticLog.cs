using System.Text;
namespace AirFlash.Core;

public static class DiagnosticLog
{
    internal const int MaxFileBytes = 256 * 1024;
    private static readonly object Gate = new();
    private static readonly Encoding Utf8 = new UTF8Encoding(false);

    public static void Write(string directory, string message)
    {
        var safe = DiagnosticText.Protect(message);
        if (safe.Length > 8192) safe = safe[..8192] + " [truncated]";
        var entry = $"{DateTimeOffset.Now:O} {safe}{Environment.NewLine}";
        lock (Gate)
        {
            Directory.CreateDirectory(directory);
            var current = Path.Combine(directory, "wpf.log");
            var length = File.Exists(current) ? new FileInfo(current).Length : 0;
            if (length + Utf8.GetByteCount(entry) > MaxFileBytes)
            {
                if (length > MaxFileBytes) File.Delete(current);
                else File.Move(current, Path.Combine(directory, "wpf.previous.log"), true);
            }
            File.AppendAllText(current, entry, Utf8);
        }
    }
}
