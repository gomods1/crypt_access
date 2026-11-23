# Makes a GitHub release of Crypt Access from this PC, checking each step. Stops at the first failure.
#
#   .\tools\release.ps1 -NotesFile path\to\notes.md            full release
#   .\tools\release.ps1 -NotesFile path\to\notes.md -DryRun    everything except publishing
#
# Steps:
#   1. Checks: version in mod.json not yet released, git clean and pushed, translations (check_lang.py).
#   2. Starts the game if needed and waits for the dev console, then builds the .necromod package with
#      the game's packer (build_package.py). Only the running game can build it.
#   3. Closes the game (the installer refuses to run while it is open) and builds the zip (package.ps1).
#   4. Gets the online installer exe from the latest release and tests the new zip with it in a sandbox:
#      install from the local zip, check the files and the config.json patch, uninstall, check clean-up.
#   5. Publishes the release (tag v<version> on main) with the zip, the package and the installer exe.
#   6. Tests again in a sandbox, this time installing from GitHub the way players do.
#
# The sandbox is a fake game folder (a copy of the real config.json without our entries) and a fake
# LOCALAPPDATA under %TEMP%. The real game folder and the real mods folder (the dev junction) are never
# touched by the installer runs.
param(
	[string]$NotesFile,
	[switch]$DryRun,
	[switch]$CheckOnly,
	[string]$GameDir = "S:\steam\steamapps\common\Crypt of the NecroDancer",
	[string]$Repo = "gomods1/crypt_access"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$mod = Join-Path $root "mod\CryptAccess"
$version = (Get-Content -Raw (Join-Path $mod "mod.json") | ConvertFrom-Json).version
$tag = "v$version"
$zip = Join-Path $root "dist\CryptAccess-$tag.zip"
$package = Join-Path $root "dist\CryptAccess-$version.necromod"
$exeName = "CryptOfTheNecroDancerAccessibilityInstaller.exe"
$exe = Join-Path $root "dist\installer\$exeName"
$realConfig = Join-Path $GameDir "Necrodancer64\config.json"

function Step($text) { Write-Host ""; Write-Host "== $text" }
function Fail($text) { throw "RELEASE STOPPED: $text" }
function Run-Native([string]$what, [scriptblock]$block) {
	& $block
	if ($LASTEXITCODE -ne 0) { Fail "$what failed (exit $LASTEXITCODE)" }
}

if (-not $CheckOnly) {
	# ---------------------------------------------------------------- 1. checks
	Step "Checks for $tag"
	if (-not $NotesFile -or -not (Test-Path $NotesFile)) { Fail "give -NotesFile with the release notes (markdown)" }
	$NotesFile = (Resolve-Path $NotesFile).Path
	if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Fail "the GitHub CLI (gh) is not installed" }
	gh release view $tag -R $Repo *> $null
	if ($LASTEXITCODE -eq 0) { Fail "$tag is already released. Bump the version in mod\CryptAccess\mod.json first." }
	$dirty = git -C $root status --porcelain
	if ($dirty) { Fail "uncommitted changes:`n$($dirty -join "`n")" }
	Run-Native "git fetch" { git -C $root fetch -q origin main }
	$head = git -C $root rev-parse HEAD
	$remote = git -C $root rev-parse origin/main
	if ($head -ne $remote) { Fail "HEAD ($head) is not origin/main ($remote). Push first." }
	Run-Native "translation check (tools\check_lang.py)" { python (Join-Path $root "tools\check_lang.py") | Out-Null }
	if (-not (Test-Path $realConfig)) { Fail "game config not found: $realConfig" }
	"ok: $tag not released, git clean and pushed, translations complete"

	# ---------------------------------------------------------------- 2. package (needs the game)
	Step "Package (game's packer)"
	function Test-DevConsole {
		$r = python (Join-Path $root "tools\dev.py") "return 1" 2>$null | Select-Object -Last 1
		return ($r -eq "1")
	}
	if (-not (Get-Process Necrodancer -ErrorAction SilentlyContinue)) {
		& (Join-Path $root "tools\launch.ps1") -GameDir $GameDir | Out-Null
		"game started"
	}
	$deadline = (Get-Date).AddMinutes(3)
	while (-not (Test-DevConsole)) {
		if ((Get-Date) -gt $deadline) { Fail "the dev console did not answer (is mod\CryptAccess\dev\enabled there?)" }
	}
	"dev console answers"
	Run-Native "package build (tools\build_package.py)" { python (Join-Path $root "tools\build_package.py") | Select-Object -Last 2 }
	if (-not (Test-Path $package)) { Fail "package missing: $package" }

	# ---------------------------------------------------------------- 3. close game, zip
	Step "Close the game, build the zip"
	$p = Get-Process Necrodancer -ErrorAction SilentlyContinue
	if ($p) {
		$p.CloseMainWindow() | Out-Null
		if (-not $p.WaitForExit(20000)) { Fail "the game did not close; close it and run again" }
		"game closed"
	}
	& (Join-Path $PSScriptRoot "package.ps1")
	if (-not (Test-Path $zip)) { Fail "zip missing: $zip" }
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	$z = [IO.Compression.ZipFile]::OpenRead($zip)
	try {
		$names = $z.Entries | ForEach-Object FullName
		$bad = $names | Where-Object { $_ -match "DevConsole|/dev/|_speech\.log" }
		if ($bad) { Fail "zip contains dev files: $($bad -join ', ')" }
		if ($names -notcontains "CryptAccess/package/CryptAccess-$version.necromod") { Fail "zip lacks the package" }
		"zip ok: $($names.Count) entries"
	} finally { $z.Dispose() }
}

# ---------------------------------------------------------------- sandbox installer test
New-Item -ItemType Directory -Force (Split-Path $exe) | Out-Null
Step "Installer exe from the latest release"
Run-Native "installer download" { gh release download -R $Repo -p $exeName -D (Split-Path $exe) --clobber }
"got $exe"

function Invoke-Installer($sandbox, $game, [string[]]$answers, $name) {
	$la = Join-Path $sandbox "LocalAppData"
	$in = Join-Path $sandbox "$name.in.txt"
	$out = Join-Path $sandbox "$name.out.txt"
	[IO.File]::WriteAllText($in, (($answers + "4") -join "`r`n") + "`r`n")
	$saved = $env:LOCALAPPDATA
	try {
		$env:LOCALAPPDATA = $la
		# Never let the installer see the real LOCALAPPDATA: the dev mod folder there is a junction to
		# the source, and an uninstall would delete the source.
		if ($env:LOCALAPPDATA -ne $la -or -not $la.StartsWith($env:TEMP)) { Fail "sandbox LOCALAPPDATA not set" }
		$proc = Start-Process -FilePath $exe -ArgumentList "--cli" -RedirectStandardInput $in `
			-RedirectStandardOutput $out -RedirectStandardError (Join-Path $sandbox "$name.err.txt") `
			-NoNewWindow -PassThru -Wait
	} finally { $env:LOCALAPPDATA = $saved }
	$text = Get-Content -Raw $out
	if ($text -match "(?m)^Error: (.*)$") { Fail "installer ($name): $($Matches[1])" }
	return $text
}

function Test-Sandbox([string]$mode) {
	$sandbox = Join-Path $env:TEMP "CryptAccessReleaseCheck\$mode"
	if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
	$game = Join-Path $sandbox "Crypt of the NecroDancer"
	$la = Join-Path $sandbox "LocalAppData"
	New-Item -ItemType Directory -Force (Join-Path $game "Necrodancer64"), $la | Out-Null
	# A config.json as Steam ships it: the real one without the Crypt Access entries.
	$cfg = Join-Path $game "Necrodancer64\config.json"
	$j = Get-Content -Raw $realConfig | ConvertFrom-Json
	$j.wos.game.mods.preload = @($j.wos.game.mods.preload | Where-Object { $_.name -ne "CryptAccess" })
	$j.wos.game.mods.scriptWhitelist = @($j.wos.game.mods.scriptWhitelist | Where-Object { $_ -ne "core.StandardLibrary" })
	[IO.File]::WriteAllText($cfg, ($j | ConvertTo-Json -Depth 50 -Compress), (New-Object Text.UTF8Encoding($false)))

	# The installer first offers the Steam folder it detects ("Use this path?"): answer n, give the sandbox.
	if ($mode -eq "github") {
		$text = Invoke-Installer $sandbox $game @("n", $game, "1", "y") "install"
		if ($text -notmatch "Latest version: $([regex]::Escape($tag))") { Fail "GitHub's latest release is not $tag" }
	} else {
		$text = Invoke-Installer $sandbox $game @("n", $game, "2", $zip) "install"
	}
	if ($text -notmatch "Installed (\d+) files") { Fail "installer ($mode) did not install. Output: $(Join-Path $sandbox 'install.out.txt')" }
	$count = $Matches[1]
	$modDir = Join-Path $la "NecroDancer\mods\CryptAccess"
	$installed = (Get-Content -Raw (Join-Path $modDir "mod.json") | ConvertFrom-Json).version
	if ($installed -ne $version) { Fail "installed mod.json says $installed, expected $version" }
	if (-not (Test-Path (Join-Path $modDir "package\CryptAccess-$version.necromod"))) { Fail "package not installed" }
	if (-not (Test-Path (Join-Path $modDir "lib\prism.dll"))) { Fail "prism.dll not installed" }
	if (Test-Path (Join-Path $modDir "scripts\DevConsole.lua")) { Fail "the dev console was installed" }
	if ($mode -eq "github") {
		$vf = (Get-Content (Join-Path $modDir "accessibility_installed_version.txt")).Trim()
		if ($vf -ne $tag) { Fail "version file says $vf, expected $tag" }
	}
	$j = Get-Content -Raw $cfg | ConvertFrom-Json
	if (-not ($j.wos.game.mods.preload.name -contains "CryptAccess")) { Fail "config.json preload not patched" }
	if (-not ($j.wos.game.mods.scriptWhitelist -contains "core.StandardLibrary")) { Fail "config.json whitelist not patched" }
	"install ok ($mode): $count files, version $installed, config.json patched"

	$text = Invoke-Installer $sandbox $game @("n", $game, "3", "y") "uninstall"
	if ($text -notmatch "Uninstall complete") { Fail "uninstall ($mode) did not complete" }
	if (Test-Path $modDir) { Fail "uninstall left $modDir" }
	$j = Get-Content -Raw $cfg | ConvertFrom-Json
	if (($j.wos.game.mods.preload.name -contains "CryptAccess") -or ($j.wos.game.mods.scriptWhitelist -contains "core.StandardLibrary")) {
		Fail "uninstall left Crypt Access entries in config.json"
	}
	"uninstall ok ($mode): folder removed, config.json restored"
	Remove-Item -Recurse -Force $sandbox
}

if ($CheckOnly) {
	if (-not (Test-Path $zip)) { Fail "zip missing: $zip" }
	Test-Sandbox "localzip"
	Step "Sandbox test: install from GitHub"
	Test-Sandbox "github"
	Step "Checked $tag : local zip and GitHub release install and uninstall cleanly"
	return
}

Step "Sandbox test: install from the local zip"
Test-Sandbox "localzip"

if ($DryRun) {
	Step "Dry run: not published. Built $zip and $package."
	return
}

# ---------------------------------------------------------------- 5. publish
Step "Publish $tag"
Run-Native "gh release create" {
	gh release create $tag -R $Repo --target main --title "Crypt Access $tag" --notes-file $NotesFile $zip $package $exe
}

# ---------------------------------------------------------------- 6. as players get it
Step "Sandbox test: install from GitHub"
try {
	Test-Sandbox "github"
} catch {
	Write-Host "The release is published but the install from GitHub failed: $_"
	Write-Host "Fix it, or remove the release with: gh release delete $tag -R $Repo --cleanup-tag"
	throw
}

Step "Released $tag : https://github.com/$Repo/releases/tag/$tag"
