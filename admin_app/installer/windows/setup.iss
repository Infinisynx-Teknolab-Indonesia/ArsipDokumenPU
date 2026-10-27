; ============================================================
; Arsip Dokumen PU — ADMIN SERVER — Installer Windows (Inno Setup 6)
; ============================================================
; Hasil: ArsipAdminServer_Setup_<versi>.exe
; Dipasang di PC admin / PC server. Untuk: menyetujui PC baru, mengelola
; member, mengatur email SMTP, keamanan, dan melihat log aktivitas.
;
; CARA BUILD (dari folder admin_app):
;   1. flutter build windows --release
;   2. Buka file ini di Inno Setup -> Build -> Compile
; ============================================================

#define MyAppName "Arsip PU Admin Server"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "Dinas Pekerjaan Umum"
#define MyAppExeName "arsip_admin_server.exe"
#define MyAppSourceDir "..\..\build\windows\x64\runner\Release"
; VC++ Runtime yang sama dengan installer aplikasi utama
#define VcRedist "..\..\..\installer\windows\vc_redist.x64.exe"

[Setup]
AppId={{B3D8F1A2-6C4E-4B9D-8E2F-1A7C5D3E9F40}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=ArsipAdminServer_Setup_{#MyAppVersion}
SetupIconFile=..\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes

[Languages]
Name: "indonesian"; MessagesFile: "compiler:Languages\Indonesian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat shortcut di Desktop"; GroupDescription: "Shortcut:"

[Files]
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#VcRedist}"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: VCRedistNeedsInstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Memasang komponen sistem (Microsoft Visual C++ Runtime)..."; \
  Check: VCRedistNeedsInstall; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Jalankan {#MyAppName} sekarang"; Flags: nowait postinstall skipifsilent

[Code]
function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Installed', Installed) then
    if Installed = 1 then
      Result := False;
end;
