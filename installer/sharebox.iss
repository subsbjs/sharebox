#ifndef ReleaseDir
  #error ReleaseDir must be specified
#endif
#ifndef OutputPath
  #error OutputPath must be specified
#endif
[Setup]
AppId={{420FC1BF-CC22-4B6B-8E09-B26DE6848E36}
AppName=ShareBox
AppVersion=1.1.0
DefaultDirName={localappdata}\Programs\ShareBox
DefaultGroupName=ShareBox
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputPath}
OutputBaseFilename=ShareBox-Setup-Windows-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\sharebox.exe
CloseApplications=yes
[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\ShareBox"; Filename: "{app}\sharebox.exe"
Name: "{autodesktop}\ShareBox"; Filename: "{app}\sharebox.exe"
[Run]
Filename: "{app}\sharebox.exe"; Description: "Open ShareBox"; Flags: nowait postinstall skipifsilent
