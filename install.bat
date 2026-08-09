@echo off
rem ============================================================
rem  install.bat — Windows install for obsidian-open-anywhere
rem
rem  What this does:
rem    1. Detects pythonw.exe (required; Python 3.x must be installed).
rem    2. Installs open-in-obsidian.py + config.ini into
rem       %LOCALAPPDATA%\obsidian-open-anywhere\.
rem    3. Registers .md files so every double-click is handled by
rem       open-in-obsidian.py (copy into vault inbox + open in Obsidian).
rem
rem  Re-run this script anytime you change config.ini or the source.
rem  Uninstall: uninstall.bat
rem ============================================================

setlocal enabledelayedexpansion

rem --- 1. Find pythonw.exe --------------------------------------
set "PYW="
where pythonw >nul 2>&1 && set "PYW=pythonw"
if not defined PYW (
  if exist "%LOCALAPPDATA%\Programs\Python\Python*\pythonw.exe" (
    for /f "delims=" %%P in ('dir /b /s "%LOCALAPPDATA%\Programs\Python\pythonw.exe" 2^>nul') do set "PYW=%%P"
  )
)
if not defined PYW (
  echo [ERROR] pythonw.exe not found. Install Python 3 from https://python.org ^
        (check "Add to PATH") and re-run this script.
  pause
  exit /b 1
)
echo [OK] pythonw: %PYW%

rem --- 2. Install files ------------------------------------------
set "DEST=%LOCALAPPDATA%\obsidian-open-anywhere"
if not exist "%DEST%" mkdir "%DEST%"
copy /y "%~dp0src\open-in-obsidian.py" "%DEST%\" >nul
if not exist "%DEST%\config.ini" (
  copy /y "%~dp0config.example.ini" "%DEST%\config.ini" >nul
  echo.
  echo [IMPORTANT] First run: edit %DEST%\config.ini and set vault_path ^
       to your Obsidian vault, then re-run this script.
  echo.
) else (
  echo [OK] config.ini already exists, kept as-is.
)

rem --- 3. Register .md file association (HKCU, no admin needed) --
rem Win11 24H2+: UserChoiceLatest overrides HKCU\Software\Classes defaults,
rem so it must be removed for the association below to take effect.
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.md\UserChoiceLatest" /f >nul 2>&1
reg add "HKCU\Software\Classes\.md" /ve /d ObsidianOpenAnywhereMarkdown /f >nul
reg add "HKCU\Software\Classes\ObsidianOpenAnywhereMarkdown\shell\open\command" /ve /d "\"%PYW%\" \"%DEST%\open-in-obsidian.py\" \"%%1\"" /f >nul
echo [OK] .md files are now handled by obsidian-open-anywhere.

echo.
echo Done. Double-click any .md file outside your vault and it will be ^
     copied into your vault inbox and opened in Obsidian.
pause
