# Install PodCast 0.1.0-rc.1

Run **PodCast-0.1.0-rc.1-Setup.exe**. It installs for your Windows account and
adds PodCast to the Start menu and Windows Installed apps. A desktop shortcut is
optional. The package includes the app, all required app runtimes, its audio
sender, licenses, and the complete official VB-CABLE driver package. No .NET,
Python, Rust, Visual C++ runtime or Bonjour setup is needed.

Use an x64 Windows 11 PC, the Spotify Windows app, and your HomePod on the same
reachable network. Spotify and your Spotify account are separate from PodCast.

If VB-CABLE is already installed, Setup leaves it alone. Otherwise it opens the
signed VB-Audio installer: approve Windows' administrator prompt, choose
**Install Driver**, and follow the vendor's restart instructions. PodCast never
restarts Windows automatically. If you cancel the driver setup, its complete
package remains in the installed `Support/VB-CABLE` folder for later.

On first launch, confirm **CABLE Output** in PodCast. In Windows Volume mixer,
route only Spotify to **CABLE Input**. Keep your ordinary speakers/headphones as
the Windows default and leave the cable's **Listen to this device** unchecked.
Choose your intended HomePod and start playback. Detailed steps are in the
installed `SETUP.md` and [routing guide](https://github.com/funkymonkeyjam/PodCast/blob/dd5072726418329f0caf24260b1ba8b31f4362eb/docs/setup/routing.md).

This personal installer is unsigned; its bundled VB-Audio installer is signed.
Use the repository's `SHA256SUMS.txt` to check the downloaded package. Version,
source commit, component hashes and corresponding source are beside the setup
file in the versioned release folder.

## Update or repair

Run the same installer again to repair missing app files, or a newer installer
to update. Setup closes its installed copy gracefully and preserves preferences
and pairing data. If a separate portable copy is running, choose **Quit** in that
copy first. Older versions are blocked rather than replacing a newer release.

## Uninstall

In Windows **Settings → Apps → Installed apps**, select **PodCast → Uninstall**.
You can also run `unins000.exe` in its installation folder. It removes the app,
bundled support files, shortcuts and uninstall entry. It preserves personal
settings, pairing data, logs, cached sender files and shared VB-CABLE. An app
sign-in entry is removed only when it points to this installed copy.

Windows keeps Spotify's audio route independently. To hear Spotify locally after
removal, set Spotify's output to **Default** in Volume mixer. If you separately
want to remove VB-CABLE, use VB-Audio's original installer and restart as it
instructs; other audio apps may use that shared driver.

Sleep/resume and the final two-hour listening test remain unfinished. This is a
release candidate for that testing, not a claim that final acceptance has passed.
