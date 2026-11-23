# Extracts the game's packages into game\ (gitignored) and decompiles the engine's LuaJIT bytecode
# into game\src. Re-run after every game update. Needs vendor\luajit-decompiler-v2.exe
# (https://github.com/marsinator358/luajit-decompiler-v2/releases, Mar_24_2024,
#  sha256 D98FEDF8041DF653904DB28A1DAAF65CE355487307AE49C573AE94491140BB6A).
param([string]$GameDir = "S:\steam\steamapps\common\Crypt of the NecroDancer")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$g = Join-Path $GameDir "Necrodancer64"
$out = Join-Path $root "game"
$wsp = Join-Path $PSScriptRoot "wsp_extract.py"

python $wsp "$g\NecroDancer.wsp" "$out\base"
python $wsp "$g\Compat.wsp" "$out\compat"
$patch = Get-ChildItem "$g\versions\v*.wsp" | Sort-Object { [version]($_.BaseName.TrimStart('v')) } | Select-Object -Last 1
python $wsp $patch.FullName "$out\patch"
foreach ($m in Get-ChildItem "$g\dlc\*.necromod") { python $wsp $m.FullName "$out\dlc\$($m.BaseName)" }

$dec = Join-Path $root "vendor\luajit-decompiler-v2.exe"
New-Item -ItemType Directory -Force "$out\src\base", "$out\src\patch" | Out-Null
& $dec "$out\base\scripts" -o "$out\src\base" -e lua -s -f | Out-Null
& $dec "$out\patch" -o "$out\src\patch" -e lua -s -f | Out-Null
"extracted $($patch.Name); decompiled files: " + (Get-ChildItem "$out\src" -Recurse -Filter *.lua).Count
