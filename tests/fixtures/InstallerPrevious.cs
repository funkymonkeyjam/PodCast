// Synthetic installer upgrade input, never a released PodCast application.
using System.Reflection;

[assembly: AssemblyTitle("PodCast synthetic installer fixture")]
[assembly: AssemblyDescription("Lower-version payload for disposable installer lifecycle tests only")]
[assembly: AssemblyVersion("0.0.0.0")]
[assembly: AssemblyFileVersion("0.0.0.0")]
[assembly: AssemblyInformationalVersion("0.0.0-rc.1-installer-fixture")]

internal static class InstallerPrevious
{
    private static int Main(string[] arguments)
    {
        return 0;
    }
}
