# Crypt Access installer. Run install.bat (or: powershell -ExecutionPolicy Bypass -File install.ps1).
#   install.ps1            install or update
#   install.ps1 -Uninstall remove the mod and undo the config.json change
#   install.ps1 -GameDir "D:\Games\Crypt of the NecroDancer"   use this game folder
# What it does:
#   1. Finds the game through Steam (registry and libraryfolders.vdf), or uses -GameDir.
#   2. Patches Necrodancer64\config.json: adds "core.StandardLibrary" to wos.game.mods.scriptWhitelist
#      and {"name":"CryptAccess"} to wos.game.mods.preload. A backup config.json.cryptaccess.bak is kept.
#   3. Copies the CryptAccess folder to %LOCALAPPDATA%\NecroDancer\mods\CryptAccess, and the packaged copy
#      for online play (CryptAccess-<version>.necromod) to %LOCALAPPDATA%\NecroDancer\mods.
# Steam may restore config.json after a game update or a file check: run this installer again then.
param(
    [string]$GameDir = "",
    [switch]$Uninstall,
    [switch]$NoPause,
    [switch]$SkipRunningCheck,
    [switch]$DetectOnly
)
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($text) { Write-Host $text }

function Find-SteamLibraries {
    $roots = @()
    foreach ($key in @("HKCU:\Software\Valve\Steam", "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam")) {
        try {
            $item = Get-ItemProperty -Path $key -ErrorAction Stop
            foreach ($name in @("SteamPath", "InstallPath")) {
                if ($item.$name) { $roots += ($item.$name -replace "/", "\") }
            }
        } catch { }
    }
    $libraries = @()
    foreach ($root in ($roots | Select-Object -Unique)) {
        $libraries += $root
        $vdf = Join-Path $root "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($line in Get-Content $vdf) {
                if ($line -match '"path"\s+"([^"]+)"') { $libraries += ($Matches[1] -replace "\\\\", "\") }
            }
        }
    }
    return $libraries | Select-Object -Unique
}

function Find-Game {
    foreach ($lib in Find-SteamLibraries) {
        $candidate = Join-Path $lib "steamapps\common\Crypt of the NecroDancer"
        if (Test-Path (Join-Path $candidate "Necrodancer64\config.json")) { return $candidate }
    }
    return $null
}

function Patch-Config($configPath, [bool]$remove) {
    $text = Get-Content -Raw -Encoding UTF8 $configPath
    $config = $text | ConvertFrom-Json
    $mods = $config.wos.game.mods
    $whitelist = @($mods.scriptWhitelist)
    $preload = @($mods.preload)
    if ($remove) {
        $mods.scriptWhitelist = @($whitelist | Where-Object { $_ -ne "core.StandardLibrary" })
        $mods.preload = @($preload | Where-Object { -not ($_ -is [pscustomobject] -and $_.name -eq "CryptAccess") })
    } else {
        if ($whitelist -notcontains "core.StandardLibrary") { $mods.scriptWhitelist = @($whitelist + "core.StandardLibrary") }
        $has = $preload | Where-Object { $_ -is [pscustomobject] -and $_.name -eq "CryptAccess" }
        if (-not $has) { $mods.preload = @($preload + [pscustomobject]@{ name = "CryptAccess" }) }
    }
    $newText = $config | ConvertTo-Json -Depth 100 -Compress
    if ($newText -eq ($text | ConvertFrom-Json | ConvertTo-Json -Depth 100 -Compress)) {
        Say ("config.json is already " + ($(if ($remove) { "clean." } else { "patched." })))
        return
    }
    $backup = "$configPath.cryptaccess.bak"
    if (-not $remove -and -not (Test-Path $backup)) {
        Copy-Item $configPath $backup
        Say "Saved a backup of config.json as config.json.cryptaccess.bak."
    }
    [System.IO.File]::WriteAllText($configPath, $newText, (New-Object System.Text.UTF8Encoding($false)))
    Say ("config.json " + ($(if ($remove) { "restored." } else { "patched." })))
}

try {
    Say "Crypt Access installer."
    if (-not $SkipRunningCheck -and (Get-Process Necrodancer -ErrorAction SilentlyContinue)) {
        throw "Crypt of the NecroDancer is running. Close the game, then run the installer again."
    }
    if (-not $GameDir) { $GameDir = Find-Game }
    if (-not $GameDir -or -not (Test-Path (Join-Path $GameDir "Necrodancer64\config.json"))) {
        throw "The game folder was not found. Run the installer from a command prompt with -GameDir followed by the folder of Crypt of the NecroDancer."
    }
    Say "Game folder: $GameDir"
    if ($DetectOnly) { $code = 0; if (-not $NoPause) { Read-Host "Press Enter to close" | Out-Null }; exit 0 }
    $config = Join-Path $GameDir "Necrodancer64\config.json"
    $modsDir = Join-Path $env:LOCALAPPDATA "NecroDancer\mods"
    $target = Join-Path $modsDir "CryptAccess"

    if ($Uninstall) {
        Patch-Config $config $true
        if (Test-Path $target) {
            $item = Get-Item $target -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $item.Delete() } else { Remove-Item -Recurse -Force $target }
            Say "Removed $target."
        }
        foreach ($old in Get-ChildItem -File -Path $modsDir -Filter "CryptAccess-*.necromod" -ErrorAction SilentlyContinue) {
            Remove-Item -Force $old.FullName
            Say "Removed $($old.Name)."
        }
        Say "Crypt Access is uninstalled."
    } else {
        $source = Join-Path $here "CryptAccess"
        if (-not (Test-Path (Join-Path $source "mod.json"))) { throw "The CryptAccess folder is missing next to the installer. Extract the whole zip first." }
        Patch-Config $config $false
        New-Item -ItemType Directory -Force $modsDir | Out-Null
        if (Test-Path $target) {
            $item = Get-Item $target -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $item.Delete() } else { Remove-Item -Recurse -Force $target }
        }
        Copy-Item -Recurse $source $target
        $missing = @()
        foreach ($file in Get-ChildItem -Recurse -File $source) {
            $relative = $file.FullName.Substring($source.Length)
            if (-not (Test-Path (Join-Path $target $relative))) { $missing += $relative }
        }
        if ($missing.Count -gt 0) { throw ("These files were not copied: " + ($missing -join ", ")) }
        Say "Installed the mod in $target."
        # The packaged copy online sessions need, next to the mod folder; older versions are removed so the
        # game never picks a stale package.
        $version = (Get-Content -Raw (Join-Path $source "mod.json") | ConvertFrom-Json).version
        $package = Join-Path $source "package\CryptAccess-$version.necromod"
        foreach ($old in Get-ChildItem -File -Path $modsDir -Filter "CryptAccess-*.necromod" -ErrorAction SilentlyContinue) {
            if ($old.Name -ne "CryptAccess-$version.necromod") { Remove-Item -Force $old.FullName }
        }
        if (Test-Path $package) {
            Copy-Item -Force $package $modsDir
            Say "Installed the online package CryptAccess-$version.necromod."
        }
        Say "Done. Start the game; you should hear: Crypt Access loaded. Press F1 for help."
    }
    $code = 0
} catch {
    Say ("Error: " + $_.Exception.Message)
    $code = 1
}
if (-not $NoPause) { Read-Host "Press Enter to close" | Out-Null }
exit $code
