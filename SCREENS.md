# Screen inventory

Status words: verified (exercised in the running game, speech log checked), generic (read by the generic
MenuReader, not opened in a test yet), gap (known not to read well). Menu names come from
`event.menu.add` in the decompiled source. Last update: 2026-11-23, game v4.2.1-b5713.

## Boot and first run

- Title screen (cutscene SPLASH with showVersion): verified, CutsceneReader.
- Logo splash ("Brace Yourself Games"): verified. Seizure warning and loading page: written, not seen (already dismissed on this save). Saved-run restore ("Cargando intento guardado") and its pause menu: verified.
- Story cutscenes (cutscene STORY): verified with Cadence's first cutscene; subtitles are spoken as they appear.
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
- bestiary (the image-framed confirm and message boxes: Bard confirmation, character unlock notices): verified.
- runSummary after a win ("¡Has ganado!"): verified. replaySelector (replays listed with date, mode, character, score), weeklyChallenge, retry, win: verified by the menu crawl.
- networkMultiplayer, networkHost (host settings, visibility descriptions, unavailable state) and localCoop (adding and removing a player, announced): verified. A local co-op run with two players: verified (mod follows player 1, partner death announced as such). Hosting an online (IP) session: verified that the game unmounts unpacked Crypt Access. networkJoin, networkJoinUDP, networkLobbySettings, networkPlayerList, inviteFriend, blockList: verified by the menu crawl. networkGameBrowser: not opened (it queries online lobbies).
- modList, modConfig: verified by the menu crawl. modGrid (the Mods screen from Customize): verified; tool buttons speak their toolLabel and mod tiles their name from the tile id. Mod creation tools and mod.io sign-in menus: generic (not opened: they start uploads or account flows).
- feedback (segmented choices read as "Error, option 1 of 3"), gameError, audioError, accountNotification: verified by the menu crawl. onlineFeatureCheck and globalNotification open empty without a server message; feedbackConfirm follows sending (not sent).
- autoSaveLoad ("Loading saved run") and autoSaveConfirmLoad ("restore last session?"): verified.

## Not menus

- Character grid (necro.client.CharacterSelector, "Choose your character"): verified, CharSelectReader (name, locked, ready).
- Lobby level: verified (stairs with names and lock state, NPC labels, character room selectors with stats, doors, the diamond shop and an item unlock).
- Dungeon levels: verified on depth 1 floors 1, 2 and 4, depth 2 (tar, growing floors), depth 3 (hot coals, ice), depth 4 (ooze, catacomb walls, pawnbroker), depth 5 (wired doors and floors). Scanner, route, beacon, cues, HUD keys, shop prices (gold and diamonds), miniboss, stairs.
- Run end prompt ("You died! Press Up+Down to continue"): verified.
- Boss splash: verified ("Jefe: Orquestopo" on 1-4; King Conga fight and kill announced).
- Flyaways (pickups, Missed!, groove chain, NPC calls, exit unlocked): verified.
- HUD text overlay (song ended): written, not seen yet.
- Credits roll: verified, each line is spoken as it scrolls in (CreditsRenderer global "credits").
- Key rebinder overlay: verified (label and current binding; mod hotkeys off while it waits).
