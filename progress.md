# Crypt Access: progress and plan

Blind-accessibility mod for Crypt of the NecroDancer (Steam, v4.2.1-b5713, Synchrony engine). Players are fully blind.

Read first in every new session:

- `NOTEBOOK.md`: proven facts, decisions, pitfalls, test log (project memory).
- `CLAUDE.md`: project rules. `SCREENS.md`: the screen inventory and each screen's status.
- `C:\Users\Nitropc\code\mods\starting_points\template_roguelike.md`: the methodology.

## Where we are (2026-11-23, end of session 2)

Done and exercised in the running game (speech log and screenshots, driven by the dev console):

- M1 First minutes: title screen, latency calibration (with a hint for the visual step), confirm dialogs,
  latency options, every generic menu (title, messages, selected entry, value, position, unavailable,
  table rows, section headings), text fields (typed and deleted characters), F1 help lists, R repeat,
  Ctrl+arrow review buffers, mod settings in Options, Mod settings, Crypt Access.
- M2 Lobby: stairs named with lock state, NPC and sign labels, doors, the character room (bump a
  selector, confirm), the character grid of the session lobby (name, locked, ready), extra modes page
  (Rhythm: No beat).
- M3 Dungeon: scanner with categories, details (health, next move, facing, price and affordability,
  item and shrine descriptions, miniboss guarding the exit), review cursor, surroundings, route guide (N),
  unexplored-area route (U), beacon (B) following the route, positional cues (enemies, danger, items,
  walls, metronome), HUD keys (H, G, I with item key combos, L, M), events (damage taken with attacker
  and hearts, hits and kills, gold and diamonds, level start, character change), flyaways (pickups,
  Missed, groove chain, NPC calls with a cooldown, exit unlocked), run summary prompt and menu, death.
- M4 Rhythm: freeze key (Space) with the game's count-in, Bard and No beat mode pointed to in help.
- M5: shops (gold and diamonds), shrines, boss splash, story cutscene subtitles, credits, song-end overlay.
- M6: installer (`installer\install.ps1`, `install.bat`, `uninstall.bat`) tested in a sandbox and with
  Steam detection; `tools\package.ps1` builds `dist\CryptAccess-v<version>.zip`; README.md and LEEME.md;
  strings in all 11 game languages (checked by tools\check_lang.py and by switching the game language live).

Also exercised later in session 2: boss floor and boss splash, a won run, zones 2 to 5, story cutscenes, credits,
key rebinding prompt, multiplayer and local co-op menus, live switch through all 11 languages, and all 20
playable characters in real runs. The shared Rust installer has an offline Crypt of the NecroDancer entry.

Not yet exercised:

- Online multiplayer sessions (they need a second player).
- The user's own test by ear (the cue design needs their judgement: pan, pitch, volume).

## Dev setup (already applied on this machine)

```
pwsh tools/dev_install.ps1
```

- Junction `%LOCALAPPDATA%\NecroDancer\mods\CryptAccess` to `mod\CryptAccess` (live reload on save).
- `mod\CryptAccess\dev\enabled` turns on the dev console (`tools\dev.py`, see NOTEBOOK.md, Dev tools).
- Test helpers: `tools\pos.lua`, `tools\walk.lua`, `tools\explore.lua`, `tools\haswant.lua`.

## Next steps

1. The user tests by ear: title to lobby to a Bard run (see the test plan given at the end of session 2).
2. Commit this project to git: nothing is committed yet (see the 2026-11-23 incident in NOTEBOOK.md).
3. Publish a GitHub repo and release if the installer should download updates instead of being offline.
