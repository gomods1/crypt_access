# Dev install: patches config.json, copies prism.dll into the mod, and links
# %LOCALAPPDATA%\NecroDancer\mods\CryptAccess to this project's mod\CryptAccess (live reload works).
# -Remove undoes all three.
param(
    [string]$GameDir = "S:\steam\steamapps\common\Crypt of the NecroDancer",
    [switch]$Remove
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$modSrc = Join-Path $root "mod\CryptAccess"
$config = Join-Path $GameDir "Necrodancer64\config.json"
$modsDir = Join-Path $env:LOCALAPPDATA "NecroDancer\mods"
$link = Join-Path $modsDir "CryptAccess"

if (Get-Process Necrodancer -ErrorAction SilentlyContinue) { throw "Close the game first." }

if ($Remove) {
    python (Join-Path $PSScriptRoot "patch_config.py") $config --remove
    if (Test-Path $link) { (Get-Item $link).Delete() }
    "removed"
    return
}

python (Join-Path $PSScriptRoot "patch_config.py") $config
$prism = "C:\Users\Nitropc\code\libs\prism\prism-windows-x64"
New-Item -ItemType Directory -Force (Join-Path $modSrc "lib") | Out-Null
Copy-Item "$prism\dynamic\release\bin\prism.dll" (Join-Path $modSrc "lib\prism.dll") -Force
New-Item -ItemType Directory -Force $modsDir | Out-Null
if (-not (Test-Path $link)) {
    New-Item -ItemType Junction -Path $link -Target $modSrc | Out-Null
}
"installed: $link -> $modSrc"
