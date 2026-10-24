#ifndef PublishPath
  #error PublishPath is required.
#endif
#ifndef ProductVersion
  #error ProductVersion is required.
#endif
#ifndef DisplayVersion
  #error DisplayVersion is required.
#endif
#ifndef OutputDir
  #error OutputDir is required.
#endif
#ifndef VBCableDir
  #error VBCableDir is required.
#endif
#ifndef RepoRoot
  #error RepoRoot is required.
#endif

#define PodCastAppId "{2B8063F6-B964-431E-ACC8-3DFC7A943E00}"
#define VendorSetup "VBCABLE_Setup_x64.exe"
#define VendorSetupHash GetSHA256OfFile(VBCableDir + "\" + VendorSetup)

[Setup]
AppId={{#PodCastAppId}
AppName=PodCast
AppVersion={#DisplayVersion}
AppPublisher=PodCast contributors
AppPublisherURL=https://github.com/funkymonkeyjam/PodCast
AppSupportURL=https://github.com/funkymonkeyjam/PodCast/issues
AppUpdatesURL=https://github.com/funkymonkeyjam/PodCast/releases
AppComments=Spotify to one HomePod; other Windows audio stays local.
VersionInfoVersion={#ProductVersion}
VersionInfoTextVersion={#DisplayVersion}
VersionInfoProductTextVersion={#DisplayVersion}
DefaultDirName={localappdata}\Programs\PodCast
DefaultGroupName=PodCast
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64os
ArchitecturesInstallIn64BitMode=x64os
MinVersion=10.0.22000
OutputDir={#OutputDir}
OutputBaseFilename=PodCast-{#DisplayVersion}-Setup
SetupIconFile={#RepoRoot}\src\AirFlash\desktop\AirFlash.App\Assets\app.ico
UninstallDisplayIcon={app}\PodCast.exe
UninstallDisplayName=PodCast
WizardStyle=modern
DisableWelcomePage=yes
DisableDirPage=yes
DisableReadyPage=yes
InfoBeforeFile={#RepoRoot}\installer\Prerequisites.txt
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes
CloseApplications=no
RestartApplications=no
AlwaysRestart=no
RestartIfNeededByRun=no
UninstallLogging=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#PublishPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#VBCableDir}\*"; DestDir: "{app}\Support\VB-CABLE"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#RepoRoot}\installer\Prerequisites.txt"; DestDir: "{app}\Support"; DestName: "PREREQUISITES.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\PodCast"; Filename: "{app}\PodCast.exe"; Parameters: "--window"; WorkingDir: "{app}"
Name: "{autodesktop}\PodCast"; Filename: "{app}\PodCast.exe"; Parameters: "--window"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\PodCast.exe"; Parameters: "--setup"; Description: "Open PodCast setup to confirm the audio source and HomePod"; Flags: nowait postinstall skipifsilent; Check: CanOpenPodCastSetup

[Code]
const
  CaptureKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture';
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  UninstallKey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#PodCastAppId}_is1';
var
  SkipDriver: Boolean;
  DriverStatus: String;

function CableInstalled: Boolean;
var
  Endpoints: TArrayOfString;
  Index: Integer;
  Endpoint, Properties, BaseName, Adapter: String;
  State: Cardinal;
begin
  Result := False;
  if not RegGetSubkeyNames(HKLM64, CaptureKey, Endpoints) then Exit;
  for Index := 0 to GetArrayLength(Endpoints) - 1 do
  begin
    Endpoint := CaptureKey + '\' + Endpoints[Index];
    Properties := Endpoint + '\Properties';
    if RegQueryDWordValue(HKLM64, Endpoint, 'DeviceState', State) and
       ((State = 1) or (State = 2)) and
       RegQueryStringValue(HKLM64, Properties, '{a45c254e-df1c-4efd-8020-67d146a850e0},2', BaseName) and
       RegQueryStringValue(HKLM64, Properties, '{b3f8fa53-0004-438e-9003-51a46e139bfc},6', Adapter) and
       (CompareText(BaseName, 'CABLE Output') = 0) and
       (CompareText(Adapter, 'VB-Audio Virtual Cable') = 0) then
    begin
      { A registered but disabled cable must not trigger a driver reinstall. }
      Result := True;
      Exit;
    end;
  end;
end;

function ParseReleaseVersion(Value: String; var Core: Int64; var Candidate: Integer): Boolean;
var
  Separator: Integer;
  CandidateText: String;
begin
  Result := False;
  Candidate := -1;
  Separator := Pos('-', Value);
  if Separator > 0 then
  begin
    if Copy(Value, Separator, 4) <> '-rc.' then Exit;
    CandidateText := Copy(Value, Separator + 4, Length(Value));
    Candidate := StrToIntDef(CandidateText, -1);
    if (Candidate < 0) or (IntToStr(Candidate) <> CandidateText) then Exit;
    Value := Copy(Value, 1, Separator - 1);
  end;
  if StrToVersion(Value, Core) then Result := VersionToStr(Core) = Value + '.0';
end;

function VersionAllowed: Boolean;
var
  InstalledVersion: String;
  InstalledCore, NewCore: Int64;
  InstalledCandidate, NewCandidate, Comparison: Integer;
begin
  Result := False;
  if not ParseReleaseVersion('{#DisplayVersion}', NewCore, NewCandidate) then
  begin
    SuppressibleMsgBox('This PodCast installer has an unsupported version label. Obtain a valid installer from the project releases.', mbError, MB_OK, IDOK);
    Exit;
  end;
  if not RegKeyExists(HKCU, UninstallKey) then
  begin
    Result := True;
    Exit;
  end;
  if not RegQueryStringValue(HKCU, UninstallKey, 'DisplayVersion', InstalledVersion) or
     not ParseReleaseVersion(InstalledVersion, InstalledCore, InstalledCandidate) then
  begin
    SuppressibleMsgBox('The installed PodCast version could not be compared safely. Remove that copy through Windows Installed apps before installing this package. Personal settings and pairing data are preserved.', mbError, MB_OK, IDOK);
    Exit;
  end;
  Comparison := ComparePackedVersion(InstalledCore, NewCore);
  Result := (Comparison < 0) or ((Comparison = 0) and ((NewCandidate = -1) or
    ((InstalledCandidate >= 0) and (InstalledCandidate <= NewCandidate))));
  if not Result then
    SuppressibleMsgBox('A newer PodCast release is already installed. Use the same or a newer installer, or remove that copy through Windows Installed apps first.', mbError, MB_OK, IDOK);
end;

function InitializeSetup: Boolean;
var
  Index: Integer;
begin
  Result := VersionAllowed;
  if not Result then Exit;
  SkipDriver := False;
  for Index := 1 to ParamCount do
    if CompareText(ParamStr(Index), '/SKIPDRIVER') = 0 then SkipDriver := True;
  Result := not WizardSilent or SkipDriver or CableInstalled;
  if not Result then
  begin
    Log('Silent installation requires an existing VB-CABLE recording endpoint or explicit /SKIPDRIVER.');
    SuppressibleMsgBox('VB-CABLE is not detected. Run Setup interactively to install the driver. /SKIPDRIVER is only for staging or an independently managed prerequisite.', mbError, MB_OK, IDOK);
  end;
end;

function StopInstalledApplication: Boolean;
var
  Executable, PreviousDirectory: String;
  ResultCode: Integer;
begin
  Executable := ExpandConstant('{app}\PodCast.exe');
  if RegQueryStringValue(HKCU, UninstallKey, 'InstallLocation', PreviousDirectory) and
     FileExists(AddBackslash(PreviousDirectory) + 'PodCast.exe') then
    Executable := AddBackslash(PreviousDirectory) + 'PodCast.exe';
  Result := not FileExists(Executable);
  if Result then Exit;
  Result := Exec(Executable, '--quit', ExtractFileDir(Executable), SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  if not Result then Log('PodCast did not confirm graceful shutdown. No process was force-terminated.');
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if not StopInstalledApplication then
    Result := 'PodCast could not close safely. Choose Quit in PodCast, then retry Setup.';
end;

function InitializeUninstall: Boolean;
begin
  Result := StopInstalledApplication;
  if not Result then
    SuppressibleMsgBox('PodCast could not close safely. Choose Quit in PodCast, then retry removal.', mbError, MB_OK, IDOK);
end;

function CanOpenPodCastSetup: Boolean;
begin
  Result := CableInstalled;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Executable: String;
  ResultCode: Integer;
begin
  if CurStep <> ssPostInstall then Exit;
  if CableInstalled then
  begin
    DriverStatus := 'VB-CABLE is already registered and was left unchanged. If CABLE Output is disabled, enable it before connecting.';
    Exit;
  end;
  if SkipDriver or WizardSilent then
  begin
    DriverStatus := 'VB-CABLE was not detected and its interactive installation was skipped. PodCast is installed but cannot stream until CABLE Output is available.';
    Exit;
  end;
  Executable := ExpandConstant('{app}\Support\VB-CABLE\{#VendorSetup}');
  if CompareText(GetSHA256OfFile(Executable), '{#VendorSetupHash}') <> 0 then
  begin
    DriverStatus := 'The bundled VB-CABLE setup did not match the verified build payload and was not run. Obtain an intact PodCast installer before installing the driver.';
    Exit;
  end;
  if not ShellExec('runas', Executable, '', ExtractFileDir(Executable), SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then
    DriverStatus := 'VB-CABLE setup was not started or elevation was cancelled. PodCast is installed but is waiting for CABLE Output.'
  else
  begin
    Log(Format('VB-CABLE interactive setup exited with code %d; checking registration rather than assuming success.', [ResultCode]));
    if CableInstalled then
      DriverStatus := 'VB-CABLE is now registered. Follow any vendor restart instruction before connecting.'
    else
      DriverStatus := 'CABLE Output is not registered yet. Complete the vendor installation and restart Windows manually if requested. Its complete setup package is retained in Support\VB-CABLE.';
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
    WizardForm.FinishedLabel.Caption := 'PodCast {#DisplayVersion} is installed.' + #13#10#13#10 + DriverStatus + #13#10#13#10 +
      'Setup never restarts Windows or changes audio routing. Confirm CABLE Output and your HomePod in PodCast. Route only Spotify to CABLE Input in Windows Volume mixer.';
end;

function CommandExecutable(Command: String): String;
var
  Boundary: Integer;
begin
  Command := Trim(Command);
  if (Length(Command) > 0) and (Command[1] = '"') then
  begin
    Delete(Command, 1, 1);
    Boundary := Pos('"', Command);
  end
  else Boundary := Pos(' ', Command + ' ');
  if Boundary > 0 then Result := Copy(Command, 1, Boundary - 1) else Result := '';
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Command: String;
begin
  if (CurUninstallStep = usUninstall) and RegQueryStringValue(HKCU, RunKey, 'PodCast', Command) and
     (CompareText(CommandExecutable(Command), ExpandConstant('{app}\PodCast.exe')) = 0) then
    RegDeleteValue(HKCU, RunKey, 'PodCast');
end;
