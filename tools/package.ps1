# Builds the release zip: dist\CryptAccess-v<version>.zip with
#   CryptAccess\ (mod.json, scripts\, sounds\, lib\prism.dll, licenses\, package\CryptAccess-<version>.necromod)
#   install.bat  uninstall.bat  install.ps1  README.md  LEEME.md
# The package (for online play) must be built first: python tools\build_package.py (game running).
# Never includes the dev console switch (mod\CryptAccess\dev), the speech log or any game file.
param([string]$Prism = "C:\Users\Nitropc\code\libs\prism\prism-windows-x64")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$mod = Join-Path $root "mod\CryptAccess"
$version = (Get-Content -Raw (Join-Path $mod "mod.json") | ConvertFrom-Json).version
$stage = Join-Path $root "dist\stage"
$zip = Join-Path $root "dist\CryptAccess-v$version.zip"

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
$out = Join-Path $stage "CryptAccess"
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item (Join-Path $mod "mod.json") $out
Copy-Item -Recurse (Join-Path $mod "scripts") (Join-Path $out "scripts")
Remove-Item (Join-Path $out "scripts\DevConsole.lua")
Copy-Item -Recurse (Join-Path $mod "sounds") (Join-Path $out "sounds")
New-Item -ItemType Directory -Force (Join-Path $out "lib") | Out-Null
Copy-Item (Join-Path $Prism "dynamic\release\bin\prism.dll") (Join-Path $out "lib\prism.dll")
New-Item -ItemType Directory -Force (Join-Path $out "licenses") | Out-Null
Copy-Item (Join-Path $Prism "NOTICE") (Join-Path $out "licenses\Prism-NOTICE")
Copy-Item -Recurse (Join-Path $Prism "LICENSES") (Join-Path $out "licenses\Prism-LICENSES")
# The packaged mod for online sessions (tools\build_package.py, built with the game running). The mod
# copies it into %LOCALAPPDATA%\NecroDancer\mods at launch (Package.lua); install.ps1 does it right away.
$package = Join-Path $mod "package\CryptAccess-$version.necromod"
if (-not (Test-Path $package)) { throw "Missing $package. Run python tools\build_package.py with the game running first." }
$scriptsNewer = Get-ChildItem -Recurse -File (Join-Path $mod "scripts") | Where-Object { $_.Name -ne "DevConsole.lua" -and $_.LastWriteTime -gt (Get-Item $package).LastWriteTime }
if ($scriptsNewer) { throw ("Scripts changed after the package was built (" + ($scriptsNewer.Name -join ", ") + "). Rebuild it with tools\build_package.py, and bump the version if this one was released.") }
New-Item -ItemType Directory -Force (Join-Path $out "package") | Out-Null
Copy-Item $package (Join-Path $out "package")
Copy-Item (Join-Path $root "installer\install.ps1") $stage
Copy-Item (Join-Path $root "installer\install.bat") $stage
Copy-Item (Join-Path $root "installer\uninstall.bat") $stage
Copy-Item (Join-Path $root "README.md") $stage
Copy-Item (Join-Path $root "LEEME.md") $stage

if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip
"built $zip"
