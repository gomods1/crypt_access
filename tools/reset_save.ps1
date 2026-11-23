# Resets NecroDancer to a brand-new player's state, for testing the first launch: deletes every settings
# file (%APPDATA%\NecroDancer: options, per-user settings, key bindings, mod list, mod.io login) and every
# save, replay, session and cache file in %LOCALAPPDATA%\NecroDancer.
# Kept: %LOCALAPPDATA%\NecroDancer\mods (the mod; a junction to the project in dev) and overlays (the
# game's downloaded patch data, not a setting). The game folder, including the config.json install patch,
# is never touched. Everything deleted is copied to a timestamped folder first
# (default: %TEMP%\CryptAccessSaveBackup).
# The next launch is a first launch: seizure warning, intro, title, latency calibration, tutorial, with the
# game's default language, keys and volumes, and Crypt Access re-adding itself to an empty mod list.
# The game must be closed (closed normally: a killed game skips its settings save).
# Usage: tools\reset_save.ps1 [-BackupRoot <folder>] [-NoBackup]
param(
    [string]$BackupRoot = (Join-Path $env:TEMP 'CryptAccessSaveBackup'),
    [switch]$NoBackup
)
$ErrorActionPreference = 'Stop'

if (Get-Process | Where-Object { $_.ProcessName -match 'NecroDancer|Synchrony' }) {
    Write-Error 'The game is running. Quit it normally first (killing it skips the settings save).'
}

$roaming = Join-Path $env:APPDATA 'NecroDancer'
$local = Join-Path $env:LOCALAPPDATA 'NecroDancer'
$keepLocal = @('mods', 'overlays')

$targets = @()
$targets += Get-ChildItem $roaming -Force -ErrorAction SilentlyContinue |
    ForEach-Object { @{ Item = $_; Area = 'Roaming' } }
$targets += Get-ChildItem $local -Force -ErrorAction SilentlyContinue |
    Where-Object { $keepLocal -notcontains $_.Name } |
    ForEach-Object { @{ Item = $_; Area = 'Local' } }

if (-not $targets) { Write-Host 'Nothing to reset: no settings or save files found.'; return }

if (-not $NoBackup) {
    $dest = Join-Path $BackupRoot (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')
    foreach ($t in $targets) {
        $areaDir = Join-Path $dest $t.Area
        New-Item -ItemType Directory -Force $areaDir | Out-Null
        Copy-Item $t.Item.FullName $areaDir -Recurse -Force
    }
    Write-Host "Backed up to $dest (Roaming = %APPDATA%\NecroDancer, Local = %LOCALAPPDATA%\NecroDancer)"
}

foreach ($t in $targets) {
    Remove-Item $t.Item.FullName -Recurse -Force
    Write-Host "Deleted $($t.Item.FullName)"
}
Write-Host 'Done. The next launch is a first launch: seizure warning, intro, title, latency calibration, tutorial.'
