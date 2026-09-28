#define MyAppName "ClashWave"
#define MyAppVersion "{{APP_VERSION}}"
#define MyAppPublisher "ClashWave"
#define MyAppURL "https://clashwave.wenyun.qzz.io"
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
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,ClashWave}"; Flags: nowait postinstall skipifsilent
