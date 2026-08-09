@echo off
rem ============================================================
rem  uninstall.bat — remove the .md association installed by
rem  obsidian-open-anywhere. Installed files in %LOCALAPPDATA% are
rem  kept (delete the obsidian-open-anywhere folder manually if
rem  you want them gone too).
rem ============================================================

reg delete "HKCU\Software\Classes\.md" /ve /f >nul 2>&1
reg delete "HKCU\Software\Classes\ObsidianOpenAnywhereMarkdown" /f >nul 2>&1
echo [OK] .md association restored (files in %%LOCALAPPDATA%%\obsidian-open-anywhere kept).
pause
