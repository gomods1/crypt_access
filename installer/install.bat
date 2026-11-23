@echo off
rem Installs or updates Crypt Access. Close the game first.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
