# Starts the game (64-bit) from its own folder. -Restart kills a running copy first.
param([switch]$Restart, [string]$GameDir = "S:\steam\steamapps\common\Crypt of the NecroDancer")
$p = Get-Process Necrodancer -ErrorAction SilentlyContinue
if ($p -and $Restart) { $p | Stop-Process -Force; Start-Sleep -Seconds 2 }
elseif ($p) { "already running"; return }
$dir = Join-Path $GameDir "Necrodancer64"
Start-Process -FilePath (Join-Path $dir "Necrodancer.exe") -WorkingDirectory $dir
"started"
