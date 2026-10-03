#define MyAppName "ClashWave"
#define MyAppVersion "{{APP_VERSION}}"
#define MyAppPublisher "ClashWave"
#define MyAppURL "https://leewlving.github.io/clashwave/"
#define MyAppExeName "clash_for_flutter.exe"

[Setup]
AppId={{D61AA3C2-20F9-41AC-A9F2-62E48B06E1F9}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\ClashWave
DefaultGroupName=ClashWave
PrivilegesRequired=admin
OutputDir=..\..\dist
OutputBaseFilename=ClashWave-{#MyAppVersion}-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\ClashWave"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\ClashWave"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,ClashWave}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{app}\clashwave_service.exe"; Parameters: "--uninstall"; Flags: runhidden waituntilterminated skipifdoesntexist

[Code]
var
  RestartCoreService: Boolean;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
  Helper: String;
begin
  Result := '';
  RestartCoreService := False;
  Helper := ExpandConstant('{app}\clashwave_service.exe');
  if FileExists(Helper) then
  begin
    if Exec(Helper, '--is-installed', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and
       (ResultCode = 0) then
    begin
      RestartCoreService := True;
      if not Exec(Helper, '--stop', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) or
         (ResultCode <> 0) then
        Result := '无法停止现有 ClashWave 内核服务，请重试。';
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if (CurStep = ssPostInstall) and RestartCoreService then
    Exec(ExpandConstant('{app}\clashwave_service.exe'), '--start', '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode);
end;
