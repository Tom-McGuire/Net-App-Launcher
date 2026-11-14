; Script generated for Inno Setup (6.x or newer)
; Network Suite Launcher Installer & Auto-Updater Script
; Author: Tom McGuire (io.github.tommcguire)

#ifndef AppVersion
  #define AppVersion "0.8.1.Beta"
#endif

#define MyAppName "Network Suite Launcher"
#define MyAppPublisher "Tom McGuire"
#define MyAppURL "https://github.com/Tom-McGuire/Net-App-Launcher"
#define MyAppExeName "net_app_launcher.exe"
#define MyAppId "{{C24B2B0A-272E-495B-883F-8C7F7D2C021E}}"

[Setup]
; AppId uniquely identifies this application in the Windows Registry and Add/Remove Programs
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#AppVersion}
AppVerName={#MyAppName} {#AppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Install per-user by default in %LOCALAPPDATA%\Programs\NetworkSuiteLauncher (no admin rights or UAC elevation needed)
DefaultDirName={localappdata}\Programs\NetworkSuiteLauncher
DisableProgramGroupPage=yes
PrivilegesRequired=lowest

; Output file configuration
OutputDir=..\..
OutputBaseFilename=NetworkSuiteLauncher_windows_x64_Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Compression settings
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; Silent update and running application handling:
; CloseApplications and RestartApplications allow smooth in-app updates using:
;   NetworkSuiteLauncher_windows_x64_Setup.exe /SILENT /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS
CloseApplications=yes
RestartApplications=yes
CloseApplicationsFilter=*.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Copy all build artifacts from the Flutter Windows runner release directory
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; IconFilename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
