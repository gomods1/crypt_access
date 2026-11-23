# Screen inventory

Status words: verified (exercised in the running game, speech log checked), generic (read by the generic
MenuReader, not opened in a test yet), gap (known not to read well). Menu names come from
`event.menu.add` in the decompiled source. Last update: 2026-11-23 (session 3), game v4.2.1-b5713.

## Boot and first run

- Title screen (cutscene SPLASH with showVersion): verified, CutsceneReader. The title art is described (NecroDancer, Amplified, Synchrony, Halloween and Christmas variants; NecroDancer art verified by speech log).
- Logo splash ("Brace Yourself Games"): verified. Seizure warning and loading page: written, not seen (already dismissed on this save). Saved-run restore ("Cargando intento guardado") and its pause menu: verified.
- Story cutscenes (cutscene STORY) and the two intro videos: subtitles are spoken as they appear, and a scene-by-scene description (CutsceneTimeline.lua, 25 videos, written from the video frames) is spoken between them. Verified with cutscene_cadence_1 (2026-11-23).
- latencyCalibration: verified (title, step text, mod hint for the visual step).
- confirm (skip calibration and every yes/no dialog): verified.
- latencyOptions: verified (sliders say "left and right to change").
- Tutorial level (labels, Cadence voice subtitles, key, chest): verified.

## Menus

- pause (in a run and in the lobby): verified.
- settings (Options and every sub page share this menu): verified for Options, Misc, Latency, Mod settings, Crypt Access page, Extra modes.
- optionsControls (key rebinding table): verified, rows read as "selected cell. rest of row". Rebinding prompt: verified (RebindReader).
- leaderboards: verified (rows "rank, name, time, watch").
- runSummary: verified (killer, score, duration, options).
- lobbyModeSelector: verified.
- seedEntry and other text fields: verified (typed characters, deletions, final text).
- messageBox (character unlock notices), textEntry, characterLock: verified by the menu crawl (tools/menu_crawl.py). dropdown and colorPicker only open from a parent setting (opening them alone has no entries or errors in the game).
- main, credits, changeLog, changeLanguage, changeResolution, changeSoundtrack, audioChannels (values read with each slider), audioChannelCustom, settingsOverview, settingsPresets, powerSettings, customize, touchOptions, optionsGame: verified by the menu crawl.
- bestiary (the image-framed confirm and message boxes: Bard confirmation, character unlock notices): verified; the portrait is described after the message and is the last details line (verified 2026-11-23).
- runSummary after a win ("¡Has ganado!"): verified. replaySelector (replays listed with date, mode, character, score), weeklyChallenge, retry, win: verified by the menu crawl.
- networkMultiplayer, networkHost (host settings, visibility descriptions, unavailable state) and localCoop (adding and removing a player, announced): verified. A local co-op run with two players: verified (mod follows player 1, partner death announced as such). Hosting an online (IP) session: verified that the game unmounts unpacked Crypt Access. networkJoin, networkJoinUDP, networkLobbySettings, networkPlayerList, inviteFriend, blockList: verified by the menu crawl. networkGameBrowser: not opened (it queries online lobbies); its rows are text cells (name, host, ping, players, content, mods, level), read by the row reader. networkHost: Crypt Access adds a cross-play warning on open, and a hint in F1 and the details (written; opening it was refused by the permission classifier in session 4).
- modList, modConfig: verified by the menu crawl. modVersionSelector, modCompiler, lobbyMenu, customMusic (custom soundtrack per zone), fileSelector and confirmResolution (its countdown is read as the No button's label changes): verified by the menu crawl (2026-11-23). modPriorityChanger only opens from a mod in the list. modGrid (the Mods screen from Customize): verified; tool buttons speak their toolLabel and mod tiles their name from the tile id. Mod creation tools and mod.io sign-in menus: generic (not opened: they start uploads or account flows).
- feedback (segmented choices read as "Error, option 1 of 3"), gameError, audioError, accountNotification: verified by the menu crawl. onlineFeatureCheck and globalNotification open empty without a server message; feedbackConfirm follows sending (not sent).
- autoSaveLoad ("Loading saved run") and autoSaveConfirmLoad ("restore last session?"): verified.

## Not menus

- Character grid (necro.client.CharacterSelector, "Choose your character"): verified, CharSelectReader (name, locked, ready). Control plus Up reads the portrait description (written, not yet seen in a test).
- Lobby level: verified (stairs with names and lock state, NPC labels, character room selectors with stats, doors, the diamond shop and an item unlock).
- Dungeon levels: verified on depth 1 floors 1, 2 and 4, depth 2 (tar, growing floors), depth 3 (hot coals, ice), depth 4 (ooze, catacomb walls, pawnbroker), depth 5 (wired doors and floors). Scanner, route, beacon, cues, HUD keys, shop prices (gold and diamonds), miniboss, stairs.
- Run end prompt ("You died! Press Up+Down to continue"): verified.
- Boss splash: verified ("Jefe: Orquestopo" on 1-4; King Conga fight and kill announced). The boss portrait and the arena are described (Coral Riff on 1-4 verified, 2026-11-23).
- Flyaways (pickups, Missed!, groove chain, NPC calls, exit unlocked): verified.
- HUD text overlay (song ended): verified.
- Extra-modes room (lobby): verified; altars read "Modo Sin compás, desactivado" and toggles are announced.
- Codex lore levels (lobby east): verified (trap corridor read by the scanner).
- Daily challenge: the game unloads all mods for it (log, 2026-11-23); documented in the README.
- Level editor (NecroEdit): mouse driven; the mod announces it is not supported there and turns its keys off.
- Training rooms (lobby west): behind a locked door that needs a key on this save; not entered.
- Credits roll: verified, each line is spoken as it scrolls in (CreditsRenderer global "credits"), and each monster that dances by is named with its joke name ("billed as"), or as not met yet (verified 2026-11-23).
- Key rebinder overlay: verified (label and current binding; mod hotkeys off while it waits).

## Descriptions (session 3)

- Scanner details (Control plus Up): every enemy, boss, character, shopkeeper and lobby person has a picture
  description (Describe.lua, DescXX.lua), then damage in hearts and how often it acts. 251 of 262 enemy and
  character types are covered; the rest are Synchrony co-op extras and the doppelganger. Verified on 1-1.
- First sight of each enemy kind: described once, remembered in the hidden setting describe.seen. Verified
  on 1-1 and 1-2.
- Zones: described at the first floor of each zone in a run, and boss arenas (verified 1-1 and 1-4).
- Fights (Combat.lua): grab and release, frozen and thawed, confused and back to normal, charges, mimics
  and sleepers waking, parries, enemy spells, explosions, enemies appearing. Verified: freeze, confusion,
  an enemy's confusion spell, a spawned slime appearing. Not yet seen in a test: grab, charge, wake-up,
  parry, breath spells, explosions.

## Online (session 4: written, not yet tested online)

- Session mod list: when it arrives the mod says it is on, or why the game will turn it off (not in the host's
  list, usually because of cross-play; another version).
- Chat and the game's notices: spoken (verified offline with chat.print and chat.addMessage).
- Spectating after death: "Now watching <name>" with the controls, and F1 help.
- Pauses by the host and their end; the game's "network issues" notice.
- O: the players, with character, health and position (verified offline: "no other players").
- Other players named in the scanner and in death announcements.
