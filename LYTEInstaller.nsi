!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"
!include "WinMessages.nsh"

;--------------------------------
; General Settings
;--------------------------------
Name "LYTE"
OutFile "LYTE_Installer.exe"
InstallDir "$PROGRAMFILES64\LYTE"
InstallDirRegKey HKLM "Software\LYTE" "Install_Dir"
RequestExecutionLevel admin
Unicode True

;--------------------------------
; Modern UI Settings
;--------------------------------
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Header\nsis3-metro.bmp"
!define MUI_HEADERIMAGE_RIGHT
!define MUI_WELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\nsis3-metro.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "${NSISDIR}\Contrib\Graphics\Wizard\nsis3-metro.bmp"

;--------------------------------
; Variables for config options
;--------------------------------
Var AddStartMenu
Var AddDesktop
Var InstallPython
Var InstallVLC
Var InstallVCRedist
Var ComponentsPageDialog
Var PythonCheckbox
Var VLCCheckbox
Var VCRedistCheckbox
Var ComponentsLabel

; Variables for uninstall
Var RemoveSettings

;--------------------------------
; Pages
;--------------------------------
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "license.txt"
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE DirectoryPageLeave
!insertmacro MUI_PAGE_DIRECTORY
Page custom ComponentsPageCreate ComponentsPageLeave
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\LYTE.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch LYTE"
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

;--------------------------------
; Languages
;--------------------------------
!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; Directory Page Functions
;--------------------------------

Function DirectoryPageLeave
  ; Validate install directory
  ${If} $INSTDIR == ""
    MessageBox MB_ICONEXCLAMATION "Please select an installation directory."
    Abort
  ${EndIf}
  
  ; Check if directory is writable
  GetTempFileName $0
  Delete $0
  FileOpen $0 "$INSTDIR\test.tmp" w
  ${If} $0 == ""
    CreateDirectory "$INSTDIR"
    IfFileExists "$INSTDIR\*.*" 0 dir_failed
      ; Directory exists
      Goto dir_done

      dir_failed:
        MessageBox MB_ICONSTOP "Cannot create directory $INSTDIR. Please choose a different location or run as administrator."
        Abort

      dir_done:
  ${EndIf}
  FileClose $0
  Delete "$INSTDIR\test.tmp"
FunctionEnd

;--------------------------------
; Components Page Functions
;--------------------------------

Function ComponentsPageCreate
  nsDialogs::Create 1018
  Pop $ComponentsPageDialog
  ${If} $ComponentsPageDialog == error
    Abort
  ${EndIf}

  ; Page title
  ${NSD_CreateLabel} 0 10 100% 20 "Select Components to Install"
  Pop $ComponentsLabel
  SendMessage $ComponentsLabel ${WM_SETFONT} 0 0

  ; Description
  ${NSD_CreateLabel} 0 35 100% 30 "Choose which additional components you want to install with LYTE. Uncheck any components you don't need."
  Pop $0

  ; Python component
  ${NSD_CreateCheckBox} 20 70 100% 15 "Python 3.13.6 (Required for LYTE to function)"
  Pop $PythonCheckbox
  ${NSD_SetState} $PythonCheckbox ${BST_CHECKED}

  ; VLC component
  ${NSD_CreateCheckBox} 20 90 100% 15 "VLC Media Player (For playback support)"
  Pop $VLCCheckbox
  ${NSD_SetState} $VLCCheckbox ${BST_CHECKED}

  ; VC++ Redistributable component
  ${NSD_CreateCheckBox} 20 110 100% 15 "Microsoft Visual C++ Redistributable (Required for other components)"
  Pop $VCRedistCheckbox
  ${NSD_SetState} $VCRedistCheckbox ${BST_CHECKED}

  ; Shortcuts section
  ${NSD_CreateLabel} 0 140 100% 15 "Shortcuts:"
  Pop $0
  SendMessage $0 ${WM_SETFONT} 0 0

  ${NSD_CreateCheckBox} 20 160 100% 15 "Create Start Menu shortcut"
  Pop $0
  ${NSD_SetState} $0 ${BST_CHECKED}
  ${NSD_OnClick} $0 OnStartMenuClick
  StrCpy $AddStartMenu ${BST_CHECKED}

  ${NSD_CreateCheckBox} 20 180 100% 15 "Create Desktop shortcut"
  Pop $0
  ${NSD_SetState} $0 ${BST_CHECKED}
  ${NSD_OnClick} $0 OnDesktopClick
  StrCpy $AddDesktop ${BST_CHECKED}
    
  nsDialogs::Show
FunctionEnd

Function ComponentsPageLeave
  ${NSD_GetState} $PythonCheckbox $InstallPython
  ${NSD_GetState} $VLCCheckbox $InstallVLC
  ${NSD_GetState} $VCRedistCheckbox $InstallVCRedist
FunctionEnd

Function OnStartMenuClick
  Pop $0
  ${NSD_GetState} $0 $AddStartMenu
FunctionEnd

Function OnDesktopClick
  Pop $0
  ${NSD_GetState} $0 $AddDesktop
FunctionEnd

;--------------------------------
; Install Sections
;--------------------------------

Section "Microsoft Visual C++ Redistributable" SEC_VC
  ${If} $InstallVCRedist == ${BST_CHECKED}
    DetailPrint "Downloading Microsoft Visual C++ Redistributable..."
    SetOutPath "$PLUGINSDIR"
    
    ; Show progress
    inetc::get "https://aka.ms/vs/17/release/vc_redist.x64.exe" "$PLUGINSDIR\vc_redist.x64.exe" /end
    Pop $0
    ${If} $0 != "OK"
      MessageBox MB_ICONSTOP|MB_RETRYCANCEL "Failed to download VC++ Redistributable. Error: $0. Click Retry to try again or Cancel to skip this component." IDRETRY retry_vc_download IDCANCEL skip_vc
      Goto skip_vc
      retry_vc_download:
      inetc::get "https://aka.ms/vs/17/release/vc_redist.x64.exe" "$PLUGINSDIR\vc_redist.x64.exe" /end
      Pop $0
      ${If} $0 != "OK"
        MessageBox MB_ICONSTOP "Failed to download VC++ Redistributable after retry. Skipping this component."
        Goto skip_vc
      ${EndIf}
    ${EndIf}

    DetailPrint "Installing Microsoft Visual C++ Redistributable..."
    ExecWait '"$PLUGINSDIR\vc_redist.x64.exe" /install /quiet /norestart' $0
    ${If} $0 != 0
      MessageBox MB_ICONEXCLAMATION "VC++ Redistributable installation completed with warnings. This may not affect LYTE functionality."
    ${EndIf}
    
    skip_vc:
  ${EndIf}
SectionEnd

Section "Python 3.13.6" SEC_PYTHON
  ${If} $InstallPython == ${BST_CHECKED}
    ; Check if Python is already installed
    DetailPrint "Checking if Python is already installed..."
    ClearErrors
    ReadRegStr $0 HKLM "SOFTWARE\Python\PythonCore\3.13\InstallPath" ""
    ${If} ${Errors}
      ; Try checking PATH
      nsExec::ExecToLog 'cmd /c "python --version"'
      Pop $0
      ${If} $0 == 0
        DetailPrint "Python is already installed and available in PATH."
        Goto python_installed
      ${EndIf}
      
      ; Python not found, proceed with installation
      DetailPrint "Python not found. Downloading Python installer..."
      SetOutPath "$PLUGINSDIR"
      
      inetc::get "https://www.python.org/ftp/python/3.13.6/python-3.13.6-amd64.exe" "$PLUGINSDIR\python-3.13.6-amd64.exe" /end
      Pop $0
      ${If} $0 != "OK"
        MessageBox MB_ICONSTOP|MB_RETRYCANCEL "Failed to download Python installer. Error: $0. Click Retry to try again or Cancel to skip this component." IDRETRY retry_python_download IDCANCEL skip_python
        Goto skip_python
        retry_python_download:
        DetailPrint "Retrying Python download..."
        inetc::get "https://www.python.org/ftp/python/3.13.6/python-3.13.6-amd64.exe" "$PLUGINSDIR\python-3.13.6-amd64.exe" /end
        Pop $0
        ${If} $0 != "OK"
          MessageBox MB_ICONSTOP "Failed to download Python. Skipping."
          Goto skip_python
        ${EndIf}
      ${EndIf}

      DetailPrint "Installing Python..."
      ExecWait '"$PLUGINSDIR\python-3.13.6-amd64.exe" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_doc=0 Include_tcltk=0' $0
      ${If} $0 != 0
        ; Exit code 1638 means "Another version is already installed" - treat as success
        ${If} $0 == 1638
          DetailPrint "Python is already installed on this system (exit code 1638). Skipping installation."
          Goto python_installed
        ${Else}
          MessageBox MB_ICONSTOP "Python installation failed with exit code: $0. LYTE may not function properly without Python."
          Goto skip_python
        ${EndIf}
      ${EndIf}
    ${Else}
      DetailPrint "Python 3.13 is already installed."
      Goto python_installed
    ${EndIf}

    python_installed:
    ; Wait for Python to be available in PATH
    DetailPrint "Waiting for Python to be available..."
    Sleep 3000

    DetailPrint "Installing DearPyGui via pip..."
    
    ; Try to find Python executable in common locations
    StrCpy $1 ""
    ReadRegStr $1 HKLM "SOFTWARE\Python\PythonCore\3.13\InstallPath" ""
    ${If} $1 != ""
      ; Found Python in registry, use full path
      StrCpy $1 "$1python.exe"
      IfFileExists "$1" 0 try_path_python
      DetailPrint "Using Python from registry: $1"
      nsExec::ExecToLog '"$1" -m pip install dearpygui --upgrade'
      Pop $0
      ${If} $0 == 0
        Goto pip_success
      ${EndIf}
    ${EndIf}
    
    try_path_python:
    ; Try using python from PATH (use a new cmd session to get updated PATH)
    DetailPrint "Trying Python from PATH..."
    nsExec::ExecToLog 'cmd /c "python -m pip install dearpygui --upgrade"'
    Pop $0
    ${If} $0 == 0
      Goto pip_success
    ${EndIf}
    
    ; Try with full path using common installation location (system-wide)
    StrCpy $1 "$PROGRAMFILES64\Python313\python.exe"
    IfFileExists "$1" 0 try_user_python
    DetailPrint "Trying Python from Program Files: $1"
    nsExec::ExecToLog '"$1" -m pip install dearpygui --upgrade'
    Pop $0
    ${If} $0 == 0
      Goto pip_success
    ${EndIf}
    
    try_user_python:
    ; Try user's local Python installation
    StrCpy $1 "$LOCALAPPDATA\Programs\Python\Python313\python.exe"
    IfFileExists "$1" 0 try_py_launcher
    DetailPrint "Trying Python from user AppData: $1"
    nsExec::ExecToLog '"$1" -m pip install dearpygui --upgrade'
    Pop $0
    ${If} $0 == 0
      Goto pip_success
    ${EndIf}
    
    try_py_launcher:
    ; Try using py launcher (Python 3.13)
    DetailPrint "Trying Python launcher (py -3.13)..."
    nsExec::ExecToLog 'cmd /c "py -3.13 -m pip install dearpygui --upgrade"'
    Pop $0
    ${If} $0 == 0
      Goto pip_success
    ${EndIf}
    
    ; Try using py launcher (default Python 3)
    DetailPrint "Trying Python launcher (py -3)..."
    nsExec::ExecToLog 'cmd /c "py -3 -m pip install dearpygui --upgrade"'
    Pop $0
    ${If} $0 == 0
      Goto pip_success
    ${EndIf}
    
    ; All methods failed
    MessageBox MB_ICONEXCLAMATION "Failed to install DearPyGui via pip (exit code: $0). You may need to install it manually later.$\n$\nYou can install it by running:$\npython -m pip install dearpygui --upgrade"
    Goto pip_done
    
    pip_success:
    DetailPrint "Successfully installed DearPyGui via pip"
    
    pip_done:
    
    skip_python:
  ${EndIf}
SectionEnd

Section "VLC Media Player" SEC_VLC
  ${If} $InstallVLC == ${BST_CHECKED}
    DetailPrint "Downloading VLC installer..."
    SetOutPath "$PLUGINSDIR"
    
    inetc::get "https://mirror.aarnet.edu.au/pub/videolan/vlc/3.0.21/win64/vlc-3.0.21-win64.exe" "$PLUGINSDIR\vlc-3.0.21-win64.exe" /end
    Pop $0
    ${If} $0 != "OK"
      MessageBox MB_ICONSTOP|MB_RETRYCANCEL "Failed to download VLC installer. Error: $0. Click Retry to try again or Cancel to skip this component." IDRETRY retry_vlc_download IDCANCEL skip_vlc
      Goto skip_vlc
      retry_vlc_download:
      DetailPrint "Retrying VLC download..."
      inetc::get "https://mirror.aarnet.edu.au/pub/videolan/vlc/3.0.21/win64/vlc-3.0.21-win64.exe" "$PLUGINSDIR\vlc-3.0.21-win64.exe" /end
      Pop $0
      ${If} $0 != "OK"
        MessageBox MB_ICONSTOP "Failed to download VLC. Skipping."
        Goto skip_vlc
      ${EndIf}
    ${EndIf}

    DetailPrint "Installing VLC..."
    ExecWait '"$PLUGINSDIR\vlc-3.0.21-win64.exe" /S' $0
    ${If} $0 != 0
      MessageBox MB_ICONEXCLAMATION "VLC installation completed with warnings (exit code: $0). Video playback features may be limited."
    ${EndIf}
    
    skip_vlc:
  ${EndIf}
SectionEnd

Section "LYTE Application" SEC_MAIN
  ; Ensure installation directory exists and is writable
  DetailPrint "Preparing installation directory..."
  CreateDirectory "$INSTDIR"
  IfFileExists "$INSTDIR\*.*" 0 dir_error
  SetOutPath "$INSTDIR"

  ; Download to temporary location first, then copy to final location
  DetailPrint "Downloading LYTE..."
  SetOutPath "$PLUGINSDIR"
  inetc::get "https://github.com/StroepWafel/LYTE/releases/latest/download/LYTE.exe" "$PLUGINSDIR\LYTE.exe" /end
  Pop $0
  ${If} $0 != "OK"
    MessageBox MB_ICONSTOP|MB_RETRYCANCEL "Failed to download LYTE. Error: $0. Click Retry to try again or Cancel to abort installation." IDRETRY retry_lyte_download IDCANCEL abort_install
    retry_lyte_download:
    DetailPrint "Retrying LYTE download..."
    inetc::get "https://github.com/StroepWafel/LYTE/releases/latest/download/LYTE.exe" "$PLUGINSDIR\LYTE.exe" /end
    Pop $0
    ${If} $0 != "OK"
      MessageBox MB_ICONSTOP "Failed to download LYTE. Installation aborted. (Is your internet connected?)"
      Abort
    ${EndIf}
  ${EndIf}

  ; Copy downloaded file to installation directory
  DetailPrint "Installing LYTE..."
  SetOutPath "$INSTDIR"
  CopyFiles "$PLUGINSDIR\LYTE.exe" "$INSTDIR\LYTE.exe"
  IfFileExists "$INSTDIR\LYTE.exe" 0 copy_error
  Goto install_done

  dir_error:
    MessageBox MB_ICONSTOP "Cannot create or access installation directory: $INSTDIR$\nPlease ensure you have administrator privileges and the directory is writable."
    Abort

  copy_error:
    MessageBox MB_ICONSTOP "Failed to copy LYTE.exe to installation directory. Please check permissions."
    Abort

  install_done:

  ; Create shortcuts if selected
  ${If} $AddStartMenu == ${BST_CHECKED}
    CreateDirectory "$SMPROGRAMS\LYTE"
    CreateShortcut "$SMPROGRAMS\LYTE\LYTE.lnk" "$INSTDIR\LYTE.exe" "" "$INSTDIR\LYTE.exe" 0
    CreateShortcut "$SMPROGRAMS\LYTE\Uninstall LYTE.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
  ${EndIf}

  ${If} $AddDesktop == ${BST_CHECKED}
    CreateShortcut "$DESKTOP\LYTE.lnk" "$INSTDIR\LYTE.exe" "" "$INSTDIR\LYTE.exe" 0
  ${EndIf}

  ; Write uninstall info
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE" "DisplayName" "LYTE"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE" "DisplayVersion" "1.0"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE" "Publisher" "StroepWafel"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE" "NoRepair" 1

  ; Write uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
  abort_install:
SectionEnd

;--------------------------------
; Finish Page Functions
;--------------------------------

Function .onInstSuccess
  ; Installation completed successfully
  DetailPrint "Installation completed successfully!"
FunctionEnd

;--------------------------------
; Uninstaller Section
;--------------------------------
Section "Uninstall" Uninstall
  ; Remove application executable
  Delete "$INSTDIR\LYTE.exe"

  ${If} $RemoveSettings == "1"
    ; Remove settings/config files
    Delete "$INSTDIR\banned_IDs.json"
    Delete "$INSTDIR\banned_users.json"
    Delete "$INSTDIR\config.json"
    Delete "$INSTDIR\*.log"
    ; Remove logs directory if empty
    RMDir "$INSTDIR\logs"
  ${EndIf}

  ; Remove uninstaller
  Delete "$INSTDIR\uninstall.exe"

  ; Remove shortcuts
  Delete "$SMPROGRAMS\LYTE\LYTE.lnk"
  Delete "$SMPROGRAMS\LYTE\Uninstall LYTE.lnk"
  RMDir "$SMPROGRAMS\LYTE"
  Delete "$DESKTOP\LYTE.lnk"

  ; Remove registry entries
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE"
  DeleteRegKey HKLM "Software\LYTE"

  ; Remove installation directory if empty
  RMDir "$INSTDIR"

  ; Show completion message
  MessageBox MB_ICONINFORMATION "LYTE has been successfully uninstalled from your computer."
SectionEnd


;--------------------------------
; Uninstaller Init
;--------------------------------

Function un.onInit
  ; Read installation directory from registry
  ReadRegStr $INSTDIR HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LYTE" "InstallLocation"

  ; If not found, use default
  ${If} $INSTDIR == ""
    StrCpy $INSTDIR "$PROGRAMFILES64\LYTE"
  ${EndIf}

  ; Confirm uninstall
  MessageBox MB_ICONQUESTION|MB_YESNO "Are you sure you want to completely remove LYTE and all of its components?" IDYES continue_uninstall IDNO cancel_uninstall
  cancel_uninstall:
    Abort
  continue_uninstall:

  ; Ask about removing settings
  MessageBox MB_ICONQUESTION|MB_YESNO "Do you also want to remove all settings and configuration files? (This will delete config.json, banned lists, and logs)" IDYES remove_settings IDNO keep_settings

  remove_settings:
    StrCpy $RemoveSettings "1"
    Goto done_settings

  keep_settings:
    StrCpy $RemoveSettings "0"
    Goto done_settings

  done_settings:
FunctionEnd

;--------------------------------
; Section Descriptions
;--------------------------------
; Note: Section descriptions are handled in the custom ComponentsPageCreate function



