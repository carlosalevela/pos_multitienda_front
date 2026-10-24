; ─────────────────────────────────────────────────────────────────────────────
; SIS POS — Script de InnoSetup
; Para compilar: abrir este archivo con InnoSetup 6 y presionar Build > Compile
; ─────────────────────────────────────────────────────────────────────────────

#define AppName      "SIS POS"
#define AppVersion   "1.3.0"
#define AppPublisher "SIS"
#define AppExeName   "pos_multitienda_app.exe"
#define BuildDir     "..\build\windows\x64\runner\Release"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://web-production-8ab3f.up.railway.app
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=.
OutputBaseFilename=POS_Multitienda_Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=120
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
MinVersion=10.0.17763

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear acceso directo en el Escritorio"; GroupDescription: "Accesos directos:"; Flags: checkedonce

[Files]
; Ejecutable principal
Source: "{#BuildDir}\{#AppExeName}";       DestDir: "{app}"; Flags: ignoreversion

; DLLs de Flutter / plugins
Source: "{#BuildDir}\flutter_windows.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\pdfium.dll";          DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\printing_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\url_launcher_windows_plugin.dll"; DestDir: "{app}"; Flags: ignoreversion

; Carpeta data (assets, fuentes, flutter_assets, etc.)
Source: "{#BuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Acceso directo en el menú inicio
Name: "{group}\{#AppName}";         Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"
Name: "{group}\Desinstalar {#AppName}"; Filename: "{uninstallexe}"

; Acceso directo en escritorio (opcional, según tarea elegida)
Name: "{autodesktop}\{#AppName}";   Filename: "{app}\{#AppExeName}"; IconFilename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Abrir {#AppName}"; Flags: nowait postinstall skipifsilent
