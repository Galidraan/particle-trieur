; ============================================================================
; ParticleTrieur 4.0.0 - Inno Setup Script
; Self-contained installer with embedded Python + miso
; ============================================================================

#define MyAppName "ParticleTrieur"
#define MyAppVersion "4.0.0"
#define MyAppPublisher "Microfossil"
#define MyAppURL "https://github.com/microfossil/particle-trieur"

[Setup]
AppId={{298B3E74-D0FE-47C4-8B59-423BD4B1FC42}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; Output directory relative to this .iss file
OutputDir=..\build-win
OutputBaseFilename=ParticleTrieurSetup-{#MyAppVersion}
; Use the icon if available
; SetupIconFile=..\src\main\resources\windows\ParticleTrieur.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
; Require 64-bit Windows
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Minimum Windows version (Windows 10)
MinVersion=10.0
; Disk space required (approx 2.5 GB)
DiskSpanning=no
UninstallDisplayIcon={app}\ParticleTrieur.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Main JAR
Source: "..\build-win\ParticleTrieur\ParticleTrieur.jar"; DestDir: "{app}"; Flags: ignoreversion
; Launcher batch file
Source: "..\build-win\ParticleTrieur\run.bat"; DestDir: "{app}"; Flags: ignoreversion
; Embedded Python environment with miso
Source: "..\build-win\ParticleTrieur\python-env\*"; DestDir: "{app}\python-env"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\run.bat"; IconFilename: "{app}\ParticleTrieur.ico"; Comment: "Launch ParticleTrieur"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\run.bat"; IconFilename: "{app}\ParticleTrieur.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\run.bat"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent shellexec

[Code]
// Check if Java 21 is available
function InitializeSetup(): Boolean;
var
  JavaVersion: String;
  ResultCode: Integer;
begin
  Result := True;
  // Just warn, don't block installation
  if not RegQueryStringValue(HKLM, 'SOFTWARE\JavaSoft\JDK\21', 'JavaHome', JavaVersion) then
  begin
    if not RegQueryStringValue(HKLM, 'SOFTWARE\Eclipse Adoptium\JDK\21', 'Path', JavaVersion) then
    begin
      if not RegQueryStringValue(HKLM, 'SOFTWARE\Azul Systems\Zulu\zulu-21', 'InstallationPath', JavaVersion) then
      begin
        if MsgBox('Java 21 does not appear to be installed.' + #13#10 + #13#10 +
                  'ParticleTrieur requires Java 21 to run.' + #13#10 +
                  'You can download it from:' + #13#10 +
                  'https://www.azul.com/downloads/?package=jdk#zulu' + #13#10 + #13#10 +
                  'Continue installation anyway?', mbConfirmation, MB_YESNO) = IDNO then
        begin
          Result := False;
        end;
      end;
    end;
  end;
end;
