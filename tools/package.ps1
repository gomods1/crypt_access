# Builds the release zip: dist\CryptAccess-v<version>.zip with
#   CryptAccess\ (mod.json, scripts\, sounds\, lib\prism.dll, licenses\)  install.bat  uninstall.bat
#   install.ps1  README.md  LEEME.md
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
Copy-Item (Join-Path $root "installer\install.ps1") $stage
Copy-Item (Join-Path $root "installer\install.bat") $stage
Copy-Item (Join-Path $root "installer\uninstall.bat") $stage
Copy-Item (Join-Path $root "README.md") $stage
Copy-Item (Join-Path $root "LEEME.md") $stage

if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip
"built $zip"
