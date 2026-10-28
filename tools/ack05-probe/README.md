# ACK05 passive RawInput probe

Diagnostic only. Enumerates USB VID `28BD`, PID `0202`, interface `MI_02`,
vendor-defined HID collections. A message-only window registers `RIDEV_INPUTSINK`
for the discovered usage page/usage and discards every input source except the
exact enumerated ACK05 handles. No keyboard/mouse recording, HID handles,
output reports, driver detach, input suppression, key injection or audio control.
XP-Pen should stay running so its working shortcuts remain active.

Build in native Windows PowerShell, from the repository root:

```powershell
New-Item -ItemType Directory -Force artifacts/ack05-probe | Out-Null
& C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:exe /platform:x64 /r:System.Windows.Forms.dll '/out:artifacts\ack05-probe\ack05-probe.exe' 'tools\ack05-probe\Program.cs'
```

Enumerate only (does not register a listener):

```powershell
& .\artifacts\ack05-probe\ack05-probe.exe --list
```

Listen for 30 seconds while the hardware-test owner presses the center once and
turns the dial in both directions:

```powershell
& .\artifacts\ack05-probe\ack05-probe.exe --seconds 30
```

The window never displays or takes focus. Output includes only ACK05 raw reports
(at most 1,000 lines, each at most 64 report bytes) plus center edges and totals.
Reports `02 F0` with at least 8 bytes are interpreted as full state: center is
byte 3 bit `04`, clockwise/counterclockwise is byte 7 value `01`/`02`.
`CENTER_PRESS` is a rising edge, not proof that Spotify changed. This diagnostic
does not remap the center or disable its existing roller-mode switching.

Exit codes: `0` enumeration/listening completed, `1` invalid arguments, `2` no
matching vendor collection, `3` enumeration/registration failure. `NO_REPORTS`
means registration succeeded but visibility remains unverified. A device
reconnect requires restarting the probe; source handles are intentionally fixed.

Protocol evidence: [ACK05 USB decoder](https://github.com/RomainGehrig/XPPen-ACK05-driver/blob/main/src/xppen_ack05_driver/decoder.py).
Windows API: [Raw Input overview](https://learn.microsoft.com/en-us/windows/win32/inputdev/about-raw-input).
The Linux implementation's vendor-mode setup and exclusive USB claim are
deliberately absent here. Whether Windows exposes center reports alongside the
XP-Pen driver requires an actual hardware test.
