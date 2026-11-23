# Notebook: Crypt of the NecroDancer

## Game

- Name: Crypt of the NecroDancer (Synchrony engine rewrite, v4.2.1-b5713)
- Store and install folder: Steam, app 247080, `S:\steam\steamapps\common\Crypt of the NecroDancer`
- Main executable: `Necrodancer64\Necrodancer.exe` (working directory `Necrodancer64`; `steam_appid.txt` lets it start directly)
- Build proven on: Steam build 22938426, game v4.2.1-b5713
- 32 or 64 bit: 64 bit (`Necrodancer64`; a 32-bit copy exists in `Necrodancer`, unused)
- Engine family: scripted
- Engine and version: custom C++ "WOS" engine (SDL2, BGFX/D3D11, OpenAL, FMOD Ex present) with LuaJIT 2.1 (`lua51.dll`). All game logic is Lua (bytecode with debug info) inside `NecroDancer.wsp`, patched by `versions\v4.2.1.wsp`, DLC in `dlc\*.necromod`.
- Anti-cheat or DRM: none found. Steam API only. Mods may affect leaderboards (not checked).

## Stages

- Recon (game-recon): done (2026-11-23)
- Injection (inject): done (2026-11-23). Route: the game's own Lua mod system plus a `config.json` whitelist entry.
- Speech (speech): done (2026-11-23). "Crypt Access loaded" spoken through NVDA via Prism.
- Screen text (screen-text): done for menus (title, calibration, confirm, pause, options, mod settings, leaderboard tables, run summary), cutscenes, flyaways, voice subtitles, text fields (2026-11-23, speech log).
- Scanner (scanner): done. PageDown/PageUp/Home, Shift+PageDown/Up categories, merged lobby stair labels (2026-11-23, speech log in tutorial, 1-1 and lobby).
- Autowalk (autowalk): replaced by the route guide (P) and a route-following beacon (B). Proven in 1-1 as Bard (2026-11-23).

## Resources

- Official API docs: https://vortexbuffer.com/synchrony/docs/ (module, event and component pages; mostly signatures only)
- Legacy docs: https://marukyu.github.io/synchrony-api-legacy/manual/00-readme.md.html
- Tested hand-written notes for 4.2.1 (input, rollback, level transitions): https://github.com/Ivan-Johnson/CotN-Modding
- Sandbox write-up: https://github.com/lastingParadox/CotND-Archipelago/blob/HEAD/CLAUDE.md
- Example mods with source: lastingParadox/custom-artists (menus), Nixill/Synchrony-NixLib (library), JagYayu/Synchrony-FirstPersonView (HUD text), JagYayu/NecroVC (native DLL via `core.StandardLibrary`)
- Community: mod.io https://mod.io/g/crypt, modding Discord https://discord.gg/qS88uUC9p2 (#mod-help)
- No existing blind-accessibility mod for this game was found (web, mod.io, GitHub, AccessMods hub, 2026-11-23).
- Local reference: `game/src` (decompiled engine), `game/base` (assets, i18n, bundled mods with source), `starting_points` templates.

## Decisions

- Keys (2026-11-23). Everywhere: F1 help, R repeat, Ctrl+arrows buffers. Playing: Space freeze, PageDown/PageUp scanner, Home repeat, Shift+PageDown/PageUp category, N route, U unexplored, B beacon, Shift+arrows review cursor, End cursor home, C surroundings, H/G/I/L/M HUD. Not used: W A S D (second keyboard layout), T (chat), P (multiplayer pause), Q/E (replays), Tab, punctuation (layout dependent).
- Speech interrupts on user-driven focus (menus, scanner, keys) and queues for events, per screen-reader convention.
- Positional cues use our own OGG earcons (tools/make_sounds.py) through system.game.Audio, not the game's sound groups.
- Translations: one Lua table per language (LangXX.lua), keyed by the game's language code; `tools/check_lang.py` must pass before a release.
- Shared Rust installer (user agreed 2026-11-23): C:\Users\Nitropc\code\mods\installer has an offline-only entry (GAMES[15], build_offline_cotn.bat, src/bin/cotn_offline.rs) using two new Game hooks: mod_root, and after_install/after_uninstall for the config.json patch. Tested in a sandbox with a fake LOCALAPPDATA: install, patch, uninstall, config restored exactly. Not committed (that repo also holds someone's uncommitted Rift work).
- Release: `tools/package.ps1` makes dist\CryptAccess-v<version>.zip with a PowerShell installer (install.bat/uninstall.bat). The DevConsole is excluded from releases.

- Speech goes in-process through LuaJIT ffi and `prism.dll`. No helper program and no proxy DLL. Reason: lowest latency and nothing extra to run.
- Mod install edits `Necrodancer64\config.json`: adds `core.StandardLibrary` to `wos.game.mods.scriptWhitelist` and `{"name":"CryptAccess"}` to `wos.game.mods.preload` (user agreed, 2026-11-23). The installer keeps a backup and re-applies the edit after Steam updates.
- The mod adds itself to the game's own mod list at load time (`ModList.lua`), because the game re-applies `modLoader.list` right after startup.
- Mod name and namespace `CryptAccess`. It is an unpacked mod in `%LOCALAPPDATA%\NecroDancer\mods\CryptAccess` (a junction to `mod\CryptAccess` in dev).

## Proven facts

- The mod sandbox can only `require` names matching `wos.game.mods.scriptWhitelist` (blacklist `necro.mod.*`), read from `Necrodancer64\config.json`. Source: `game/src/base/system/mod/ModScriptProvider.lua`.
- `core.StandardLibrary` returns `package`, `io`, `os`, `debug`, `jit`, raw `require`, `loadstring` and similar, but no `ffi`. The engine never registers ffi (`package.preload.ffi` is nil). Proven by the log, 2026-11-23.
- `package.loadlib("lua51.dll", "luaopen_ffi")` opens ffi. The mod caches it in `package.loaded.ffi` (it must be opened only once per Lua state). Proven: log line "ffi opened from lua51.dll", 2026-11-23.
- `prism.dll` (0.18.4) loads from the mod's `lib` folder by absolute path; the backend is NVDA. Proven by `CryptAccess_speech.log`, 2026-11-23.
- Startup order: preload mounts the mod, then the game's `Mods.lua` `loadLocalMods` cycle runs `modLoader.loadMods(targetModList)`, which unmounts anything not in `targetModList`. Source: `necro/mod/Mods.lua` lines 556-570, and the log.
- `core.ScriptLoader.getGlobal("necro.mod.Mods", "targetModList")` (through `package.loaded`) gives the live list. Appending `{name="CryptAccess", package=false}` keeps the mod loaded. Proven by the log, 2026-11-23. The script is reloaded once (remount), and `package.loaded` survives that.
- Mod scripts get globals `log` (`log.info(fmt, ...)`), `script.persist`, `event`, `L`, `print`. Reading a missing member of another module throws. Source: `core/ScriptLoader.lua`.
- Per-frame hook: `event.tick.add(name, {order="menu", sequence=N}, fn)`. The orders are listed in `necro/cycles/Tick.lua`.
- Menus: `necro.menu.Menu` `getCurrent()`, `getSelectedEntry()`, `getSelectedID()`, `getName()`; `entry.label` is a string or `function(isSelected)`; `currentMenu.label` is the title. Source: `necro/menu/Menu.lua`.
- Text markup is `\x03` codes (`#rrggbb`, `T`, `b`, `u`, `f`, `m`, `o`, `I` icon, `r` reset). Source: `necro/config/i18n/TextFormat.lua`.
- Game languages: en_US, de_DE, es_ES, fr_FR, it_IT, ja_JP, ko_KR, pt_BR, ru_RU, zh_CN, zh_TW (`game/base/i18n`).
- Rhythm options exist in code: `gameMode.rhythm.noBeat`, `gameplay.modifiers.rhythm`, rhythm leniency, `gameplay.lobbyIgnoreRhythm`. Their exact behaviour has not been checked.
- User data: `%LOCALAPPDATA%\NecroDancer` (mods, saves, replays); settings in `%APPDATA%\NecroDancer\SynchronyOptions.lua` (`["modLoader.list"]`).

- Game language on this machine is Spanish (`Translation.getSessionTranslation()` returns "es_ES"). The mod's strings live in `LangEN.lua`/`LangES.lua` (others to add before release). Proven by dev console, 2026-11-23.
- Mod-list entries need `version` (and `package`): an entry without a version made a session start show "Faltan mods: Crypt Access" and unmount the mod. `ModList.lua` now takes the version from `necro.mod.Mods.getLatestVersion`. Proven by log, 2026-11-23.
- Privileged engine modules (necro.mod.*, core.*) are reached with `Native.engineModule(name)`: it reads ScriptLoader's private `loadedScripts` through `debug.getupvalue(scriptLoader.loadScript, i)`. Proven, 2026-11-23.
- The sandbox `require` reaches `system.game.Input` and every `necro.*` except `necro.mod.*`. The raw global `require` from StandardLibrary fails for engine scripts ("loop or previous error"). Proven, 2026-11-23.
- Key names (engine, lower case, proven by logging `Input.getPressedKeys()`): letters, `f1`..`f12`, `up/down/left/right`, `home`, `pageup`, `delete`, `enter`, `escape`, `space`, `tab`, `lcontrol`, `lshift`, `lalt`. Punctuation names follow the keyboard layout (Spanish layout: the slash key is "dash"), so the mod binds no punctuation.
- `Input.appendKeyEvents({id, time, -id, time})` injects key presses the game treats as real (title skip and menu navigation work). Calling `Input.getRawKeyID` with an unknown name creates a bogus id (metatable), so only use real names.
- Title screen and boot screens are cutscenes (`necro.client.Cutscene`, `event.cutsceneBegin` with `ev.scene.type/image/showVersion`); the title is the SPLASH scene with `showVersion`. Source: `CutsceneDefinitions.lua` 304-315; proven by speech log.
- A fresh save goes: title, latency calibration (menu `latencyCalibration`), then a short tutorial run ("Starting Tutorial run" in the log). Escape on calibration opens `confirm`; Yes opens `latencyOptions` (audio/video latency sliders, Done).
- Confirm dialogs split their message into one menu entry per visual line; `Text.sentences` joins lines that continue in lower case with a space.
- Mod hotkeys run at tick order `inputContext`, sequence -10 (before `multiKeyCombo`/`inputControls`/`menu`), and use `Input.suppressKey`. F1 help proven on the calibration screen.

- Module tables of other scripts are read-only proxies: assigning `Keys.x = ...` from another script throws "Attempt to modify module member", and reading a missing member throws. Use setter functions, and `pcall` reads of optional members (Strings.lookup does).
- Lua `cond and nil or x` always gives x: a bug of this shape listed the player in the scanner.
- Entities from different calls are different proxy tables: compare `entity.id`, never the tables (`World.isPlayer`).
- The game re-simulates turns (rollback, instant replay after death), firing damage/kill events again. `Dedupe.lua` keys announcements by `Turn.getActiveTurnID()` and text; `InstantReplay.isActive()` silences them.
- Pauses are network messages (`StateControl.pauseWithoutMenu`), so `GameState.isPaused()` turns true a frame later; Freeze keeps a 1.5 s grace.
- Injected keys (`Input.appendKeyEvents`) give key presses but not text input and not held state: typing tests need `tools/SendKeys.ps1`; modifier combos use the DevConsole's `ctrl+up` syntax (Keys.setForcedModifiers); simultaneous game combos use `up&down`.
- `tools/addstrings.py -` must read stdin as UTF-8 (fixed); a cp1252 read produced mojibake in LangES.
- Mod settings declared with `Settings.user.*` appear in Options, Ajustes de mods, Crypt Access (proven 2026-11-23). Toggles read "activado/desactivado".
- Leaderboard submission is disabled while Crypt Access is loaded (the leaderboard screen says so). Proven by screenshot, 2026-11-23.
- Sounds: `system.game.Audio.createStaticSource("mods/CryptAccess/sounds/x.ogg", false, 0)` plays mod OGG files (proven: isPlaying true, length 90000 µs). Panning is done by placing the source on a unit half circle (`setPosition(h, 0, -sqrt(1-h²))`, min distance 1, attenuation 0).
- Bard (`Modo Bard`: no beat, enemies move after you) is chosen in the lobby character room by bumping its selector; a confirm dialog follows. Character selectors are `CharacterSelectorLobby` entities whose world label gives name and stats.
- The lobby: stairs are tiles (`LobbyStairs`, `LobbyLockedStairs`) with a `LabelLobby` entity on the same tile naming them. Backspace (quick restart) in the tutorial starts a real Zone 1 run.

- Test paths into hard-to-reach states (game debug code, proven 2026-11-23): `necro.client.GameSession.goToLevel(n)` jumps within a run (refused in the lobby); an all-zones run is started from the session lobby (`StateControl.enterLobby()`, `CharacterSelector.setSelectedCharacter(nil, type)`, Enter, Multizona). Story cutscenes: `Cutscene.play({type=Cutscene.Type.STORY, character="cadence", index=1})`. Credits: same with `Cutscene.Type.CREDITS` after setting `video.cutscene.displayModeCredits` to ALWAYS. Song end: `necro.client.Input.add(Action.System.SONG_ENDED)`. Language: `Translation.setSessionTranslation(code)`.
- Character type names: Cadence Melody Aria Dorian Eli Monk Dove Coda Bolt Bard Nocturna Diamond Mary Tempo Reaper (La Muerte) Goldman_Goldman Coldsteel_Coldsteel (Hatsune Miku) Sync_Chaunter Sync_Klarinetta Sync_Suzu.
- Script globals of engine scripts are read with `scriptLoader.getGlobal(script, name)` (credits lines, KeyRebinder labels).
- SynchronyOptions.lua keeps `{name="CryptAccess",package=false,version="0.1.0"}` and the mod settings after a clean quit (proven 2026-11-23).

## Pitfalls

- 2026-11-23 incident: an installer unit test ran Crypt Access's uninstall against the real %LOCALAPPDATA% path, and through the dev junction it deleted mod\CryptAccess\scripts, sounds and mod.json (not in git). Recovered from dist\CryptAccess-v0.1.0.zip (built 08:10); DevConsole.lua (never in releases) was rewritten. The test now skips games with mod_root. Commit the project, and never let a test run a game whose mod_root is outside a temp folder.
- The decompiled `.lua` files have a UTF-8 BOM; grep still works.
- Jumping to deep levels with goToLevel counts as reaching them: on 2026-11-23 it unlocked Eli, Monk and Dove on the user's save. Buying in the lobby diamond shop unlocked the Spear (Lanza). A rebind test (real Left key through SendInput) stored "Key_1073741906" for Move left and in every combo that uses Left (UP_LEFT, DOWN_LEFT, ITEM_1, ITEM_2, BOMB); each was restored with `Controls.setKeyBind(1, "action", id, 1, "<default>")` (a full `resetToDefault` was refused by the permission classifier). Never finish a rebind test with SendInput keys; cancel it instead.
- Running a downloaded exe was blocked by the auto-mode classifier. Without auto mode it runs after a normal prompt.
- Killing the game with Stop-Process skips its settings save. To check persisted settings, quit the game normally.
- The first Mods-script read fails ("unloaded script necro.mod.Mods") during the preload mount. The second mount succeeds, so this is harmless.

## Open questions

- Online multiplayer: hosting an IP session unmounts Crypt Access, because `networkMods` drops unpackaged mods online unless the advanced setting `mod.system.allowUnpackagedNetworkMods` ("Modo de desarrollo de mods de red", visible since config.multiplayer and config.modPermissive are true) is on (base/necro/mod/NetworkMods.lua 36-40, 82-125; proven by log 2026-11-23). Turning that setting on from the dev console was refused by the permission classifier. The lasting route is a packaged mod (the game sends packaged mods to every player); with that in mind the mod now stays silent and passes every key through when Native.available is false. Decision (user, 2026-11-23): document only; online play is explained in the README, no packaged release for now. Packaged route tested locally: `Mods.compile("CryptAccess")` (engineModule necro.mod.Mods) writes %LOCALAPPDATA%\NecroDancer\mods\CryptAccess-0.1.0.necromod (it packs everything in the folder, including the speech log and dev\, so exclude those before any real package); after a restart, `Mods.unload` + `Mods.load("CryptAccess", true)` + `Mods.applyChanges()` mounts it ("Mounting packed mod") and it works. Hosting a session to test it online was refused by the permission classifier; the package was deleted and the unpacked copy restored. The user then declined an online test session (2026-11-23): online multiplayer stays untested by decision.
- The user's ear test of the cue design is still to come.

- Does `SynchronyOptions.lua` keep CryptAccess in `modLoader.list` after a clean quit? (Not verified: the game was force-killed.)
- Do unpacked mods or ffi use disable leaderboards or achievements?
- The title screen ("press any key") is not a Menu: what renders it, and how do we read it?
- How do no-beat mode, rhythm leniency and the Bard character behave, and which is the best default for blind players?

## Dev tools

- `tools/launch.ps1 [-Restart]` starts the game. `tools/shot.sh name` saves `shots/name_s.png`.
- `tools/dev.py "lua"` runs Lua in the game through `DevConsole.lua` (active only when `mod/CryptAccess/dev/enabled` exists): `R(name)` requires any module, `M.Name` a mod module, `key("enter","wait",...)` injects keys, `S(v)` serializes. `--speech N` prints the last spoken lines.
- `tools/SendKeys.ps1 -Keys UP,ESC` sends real OS keys (steals focus; prefer `key()`).

## Test log

- 2026-11-23: first load. The mod mounted, then was unmounted by the game's mod list; ffi was missing.
- 2026-11-23: ModList self-registration keeps the mod loaded; ffi still missing.
- 2026-11-23: ffi opened via luaopen_ffi; "Crypt Access loaded" spoken through NVDA.
- 2026-11-23 (Claude): OS-level output check with Windows' per-application peak meter (tools/cue_meter.py, IAudioMeterInformation through comtypes; it sees the game session on the Sonar virtual device). Frozen game (no music): enemy cue peaks L/R 0.123/0.050 at 3 left, 0.220/0.120 at 1 left, 0.203/0.203 centre, mirrored on the right. Cues reach the speakers, pan symmetrically and stay audible during freeze. With music playing, the 3-tile cues are partly masked.
- 2026-11-23 (Claude): extra-modes room (altars named with their mode and on/off state, toggles announced), codex trap lore level, level editor (keys off, notice), daily challenge (the game unmounts every mod: "Starting Desafío diario (DLC) run"), lobby locked door ("¡Necesita una llave!"). Route fixes: never across stairs or bump-to-act things (altars, characters, chests, shrines, shop items) unless they are the destination; locked doors only with a key.
- 2026-11-23 (Claude): cue parameters read back from system.game.Audio (tools/cue_params.lua): position runs from (-1,0,0) at 3 tiles left through (0,0,-1) centre to (1,0,0) at 3 right; pitch 1.28 at 3 up, 0.78 at 3 down; volume 0.70 adjacent falling to 0.17 at 5 tiles. Recording the output failed: game audio goes through SteelSeries Sonar virtual devices that loopback capture does not see. Menu crawl (tools/menu_crawl.py) over every remaining menu: fixed slider values (same-spot text cells), grid neighbours read as rows, mod browser icon buttons (toolLabel, tile ids), segmented choices ("Error, opción 1 de 3").
- 2026-11-23 (Claude): multiplayer: host menu read (visibility set to Privado, then IP address), hosting unmounted the mod (unpackaged); local co-op player added and removed (announced), two-player co-op run (mod follows player 1, partner death fixed to "Tu compañero ha muerto"); logo splash read; escape on the crash-restore dialog quits the game (game behaviour).
- 2026-11-23 (Claude): with the user's approval, unlocked Melody, Aria, Dorian, Coda, Bolt and Diamond and ran each, so all 20 playable characters are verified in real runs (Melody and Aria story intros read). After the file restore: clean load, 0 errors, crash-restore dialog read, regression of F1, scanner, Ctrl+Up, H, I, C, U, Space.
- 2026-11-23 (Claude): boss floor 1-4 (splash "Jefe: Orquestopo", King Conga killed), a won Zone 1 run ("¡Has ganado!"), zones 2 to 5 tile and entity names, hot coals and ice details, story cutscene subtitles, credits lines, key rebinding prompt, multiplayer and local co-op menus, unspent-diamonds dialog, diamond shop purchase, song-end overlay, saved-run restore, shrine details, live language switch through all 11 languages (HUD keys answered in each), real runs started with Nocturna, Tempo, Mary, Klarinetta, La Muerte, Chaunter, Suzu, Hatsune Miku, Goldman, Eli, Monk, Dove (plus Cadence and Bard): health, inventory, scanner and events read for each.
- 2026-11-23 (Claude): Cadence rhythm run: metronome cues fire per beat, freeze and resume with count-in work; character grid reader; extra modes page (Rhythm option); key rebinding table rows; installer sandbox install and uninstall (config identical apart from our entries), Steam detection finds S:; readers exercised with Nocturna, Tempo, Mary, Hatsune Miku, Cadence and Bard kits; all 11 language tables load in the game.
- 2026-11-23 (Claude, by dev console and speech log): title, calibration skip, latency options, tutorial (voice subtitles, key pickup, chest, dagger, slime kill, hits), Backspace to a 1-1 run, pause menu, back to lobby, lobby scanner, character room, Bard selection, 1-1 as Bard (route, kills, damage, freeze, death, run summary), leaderboard rows, options, mod settings toggles, seed text field echo.
