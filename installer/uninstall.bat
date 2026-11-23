@echo off
rem Removes Crypt Access and restores the game's config.json entries.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Uninstall %*
