; ============================================================
; Arsip Dokumen PU — Installer Windows (Inno Setup 6)
; ============================================================
; Hasil: ArsipDokumenPU_Setup_<versi>.exe — satu file yang bisa dipasang di
; PC Windows 10/11 64-bit mana saja (tidak perlu Flutter/Python di PC tujuan).
;
; Installer ini:
;   1. Memasang aplikasi ke C:\Program Files\Arsip Dokumen PU
;   2. Memasang Microsoft Visual C++ Runtime bila belum ada (wajib untuk
;      aplikasi Flutter Windows — tanpa ini muncul error "VCRUNTIME140.dll
;      not found"). File vc_redist.x64.exe ikut dibundel -> bisa offline.
;   3. Membuat shortcut di Desktop dan Start Menu
;   4. Menyediakan Uninstall di "Apps & features"
;   Data pengguna (database offline + antrian upload) disimpan di
;   %APPDATA%\ArsipDokumenPU dan TIDAK dihapus saat uninstall/upgrade.
;
; CARA BUILD:
;   1. flutter build windows --release   (di folder utama proyek)
;   2. Buka file ini di Inno Setup -> Build -> Compile
; ============================================================

#define MyAppName "Arsip Dokumen PU"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif
#define MyAppPublisher "Dinas Pekerjaan Umum"
#define MyAppExeName "arsip_dokumen.exe"
#define MyAppSourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{7C2E4A91-5D3B-4F6E-9A1C-3F8B2D6E0A51}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=ArsipDokumenPU_Setup_{#MyAppVersion}
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
; tutup aplikasi yang sedang berjalan saat upgrade
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "indonesian"; MessagesFile: "compiler:Languages\Indonesian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat shortcut di Desktop"; GroupDescription: "Shortcut:"
Name: "autostart"; Description: "Jalankan otomatis saat Windows menyala (supaya antrian upload terkirim)"; GroupDescription: "Opsi:"; Flags: unchecked

[Files]
; Aplikasi Flutter hasil build (exe + dll + data/)
Source: "{#MyAppSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Visual C++ Runtime (dipasang hanya bila belum ada)
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: VCRedistNeedsInstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "ArsipDokumenPU"; \
  ValueData: """{app}\{#MyAppExeName}"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; \
  StatusMsg: "Memasang komponen sistem (Microsoft Visual C++ Runtime)..."; \
  Check: VCRedistNeedsInstall; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "Jalankan {#MyAppName} sekarang"; Flags: nowait postinstall skipifsilent

[Code]
// VC++ 2015-2022 x64 sudah terpasang?
function VCRedistNeedsInstall: Boolean;
var
  Installed: Cardinal;
begin
  Result := True;
  if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Installed', Installed) then
    if Installed = 1 then
      Result := False;
end;
