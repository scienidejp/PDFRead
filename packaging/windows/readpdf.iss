#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef StageDir
  #define StageDir "..\..\target\readpdf-windows-package"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist\release"
#endif
#ifndef IconPath
  #define IconPath "..\..\assets\app-icon\readpdf.ico"
#endif

[Setup]
AppId={{F2E8E47C-2EAB-4D5F-B0F6-7B59E33BD0D8}
AppName=ReadPDF
AppVersion={#AppVersion}
AppPublisher=ReadPDF
DefaultDirName={autopf}\ReadPDF
DefaultGroupName=ReadPDF
UninstallDisplayIcon={app}\readpdf.exe
SetupIconFile={#IconPath}
OutputDir={#OutputDir}
OutputBaseFilename=readpdf-{#AppVersion}-windows-x64-setup
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
LicenseFile={#StageDir}\LICENSE-MIT
InfoAfterFile={#StageDir}\NOTICE

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#StageDir}\readpdf.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\models\*"; DestDir: "{app}\models"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#StageDir}\LICENSE-MIT"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\LICENSE-APACHE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\NOTICE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#StageDir}\LICENSE-document.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\ReadPDF"; Filename: "{app}\readpdf.exe"
Name: "{autodesktop}\ReadPDF"; Filename: "{app}\readpdf.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\readpdf.exe"; Description: "Launch ReadPDF"; Flags: postinstall nowait skipifsilent
