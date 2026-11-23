# Crypt Access

Crypt Access makes Crypt of the NecroDancer (Steam, Synchrony version 4.2) playable without sight. It speaks
through your screen reader (NVDA, JAWS, Narrator, or Windows speech when no screen reader runs) and adds
positional sounds for enemies, items, walls and exits.

## Install

The easiest way: download `CryptOfTheNecroDancerAccessibilityInstaller.exe` from the latest release at
https://github.com/gomods1/crypt_access/releases and run it. It finds the game, downloads the mod, and can
update or uninstall it later. Or install from the zip:

1. Close the game.
2. Extract the whole zip to any folder.
3. Run `install.bat`. It finds the game through Steam, copies the mod to
   `%LOCALAPPDATA%\NecroDancer\mods\CryptAccess`, and adds two entries to the game's
   `Necrodancer64\config.json` (a backup `config.json.cryptaccess.bak` is kept).
4. Start the game. You hear "Crypt Access loaded. Press F1 for help."

After a game update, or after Steam verifies the game files, `config.json` may be restored. If the game
starts silent, run `install.bat` again.

If the game is not found, open a command prompt in the extracted folder and run:

```
install.bat -GameDir "D:\Path\To\Crypt of the NecroDancer"
```

To remove the mod, run `uninstall.bat`.

Notes:

- Leaderboard submission is turned off by the game while any script mod is loaded.
- The mod follows the game's language (English, Spanish, German, French, Italian, Japanese, Korean,
  Brazilian Portuguese, Russian, Simplified and Traditional Chinese).

## First steps

- The title screen says "Press any key". On a new save the latency calibration follows: its first step
  is visual, so press Escape and confirm Yes to skip it, or press Up on each beat of the music.
- A short tutorial starts on a new save. Backspace skips it.
- In the lobby, use the scanner (Page Down) to find the stairs: Zone 1, Character selection, Extra modes
  and others. Walk onto a staircase to use it.
- For turn-based play, choose Bard in the character room (walk into him and confirm), or set Rhythm to
  "No beat" in the extra modes options. With other characters you move on the beat of the music.

## Keys

Everywhere:

- F1: help for the current screen, as a list. Up and Down read it, Escape closes it.
- R: repeat the last thing said.
- Control plus Up or Down: read the details of what was last focused (an enemy's health and next move, an
  item's price and description, a setting's details), line by line.
- Control plus Left or Right: switch between the Details, Events, Surroundings and Inventory lists.

In menus the game's own keys work (arrows, Enter, Escape, Left and Right to change values). Each menu says
its title, its message and the selected entry with its position. Text fields echo what you type.

While playing:

- Arrows: move, dig and attack. The game's item combinations (for example Up plus Down to throw) are
  listed at the end of the inventory list (I, then Control plus Up).
- Space: freeze the game to think; Space again resumes with a count-in.
- Page Down and Page Up: the next and previous thing in sight, nearest first, with its direction in tiles
  ("Skeleton, 2 left, 1 up, 1 of 5"). Home repeats it with a fresh position.
- Shift plus Page Down or Page Up: scanner category (all, enemies, items, exits and doors, characters and
  shrines, traps, signs).
- N: the walkable route to the thing selected in the scanner ("3 right, 2 down, dig up").
- U: the route to the nearest unexplored area.
- B: beacon. A sound plays on every beat from the next turn of the route to the selected thing (or the
  unexplored area) until you get there. B again turns it off.
- Shift plus arrows: move a review cursor over the map without moving; End puts it back on you.
- C: the four tiles around you.
- H: health. G: gold and diamonds. I: inventory. L: depth, floor, song time left and whether the exit is
  locked. M: coin multiplier.

## Sounds

- Enemies buzz, items chime, walls make a soft thud after each of your moves.
- Left and right are stereo. Higher pitch means above you on the map, lower pitch below you. Louder is
  closer.
- A sharp rising sound means an enemy next to you acts on the next beat.

## Descriptions of what is on screen

- Cutscenes: the story and intro videos are described scene by scene between the spoken lines, for
  example "Her shovel breaks into the ground and purple smoke bursts out around her". The title screens
  are described too, and during the credits each monster that dances by is named.
- Characters, enemies, bosses and shopkeepers: select one with Page Down, then Control plus Up reads its
  health and next move, what it looks like and how it behaves ("It bounces up and down between two
  tiles"), how much damage it does and how often it acts. The character grid and the portrait dialogs
  (character unlocks, the Bard confirmation) describe the portrait.
- The first time you see a new kind of enemy, it is described once ("New: Blue Slime. A tall blue
  slime..."). The mod remembers which kinds you have already met.
- Places: each zone's look is described when you first enter it in a run, and boss floors and bosses
  when their splash screen shows.
- Fights: the mod says when an enemy grabs you or lets go, when you are frozen or confused and when that
  ends, when an enemy charges, a mimic or sleeping enemy wakes up, a blademaster parries, an enemy casts a
  spell (fire or ice breath, lightning, wind, confusion, summoning), an explosion goes off, or an enemy
  appears out of nowhere.

## Settings

In the game: Options, Mod settings, Crypt Access. There you can turn the enemy, item and wall sounds on or
off, set their range and volume, add a metronome tick, freeze automatically at the start of each floor,
and choose whether hits on enemies and menu positions are spoken. Four switches turn the descriptions on
or off: cutscenes and title screens, new kinds of enemies, fights, and zones, boss arenas and bosses.

## Modes where the mod cannot help

- The daily challenge: the game unloads every mod for it, so the game is silent there.
- The level editor: it is worked with the mouse. The mod says so when you enter it and turns its own
  keys off so they reach the editor.

## Multiplayer

- Local co-op (two players on one computer) works: the mod follows player 1, lists the other player in
  the scanner with their name, and says when they die.
- Online games work when every player has the same Crypt Access package:
  - The game only takes packaged mods into an online game, and every player loads exactly the host's
    mods. The installer puts the package `CryptAccess-<version>.necromod` in
    `%LOCALAPPDATA%\NecroDancer\mods`, and the mod puts it back there each time the game starts. When you
    host, the game switches Crypt Access to this package by itself.
  - Your friends need the same file: download `CryptAccess-<version>.necromod` from the same release and
    put it in their `%LOCALAPPDATA%\NecroDancer\mods` folder (the game creates it). They do not run the
    installer, so the mod stays silent on their computer and leaves every key to their game.
  - Host by IP address, or turn off "Enable cross-play" in the host menu before hosting. With
    cross-play on, the game turns off every mod its own server has not approved, Crypt Access included.
    The host menu warns you about this.
  - When the session's mod list arrives, the mod says "Crypt Access is on in this online session", or
    explains why the game is about to turn it off (cross-play, a missing package, another version).
- In an online game:
  - Chat messages and the game's notices (a player joins or leaves) are read aloud. T opens the chat.
    Settings: "Read chat messages aloud".
  - O: the players in the game, with character, health and where they are. Control plus Up reads the
    list one player at a time.
  - Other players are named in the scanner ("Ana, Melody"), and their deaths are announced with their
    name.
  - After you die you watch another player: the mod says who, Left or Right changes, Enter joins again
    when the game allows it. The scanner and the HUD keys follow the player you watch.
  - Pauses by the host, the end of the pause, and the game's "network issues" notice are spoken. Only
    the host can pause with Space.
- The daily challenge unloads every mod, online or not.

## Credits and licences

- Speech through Prism; its licences are in `CryptAccess\licenses`.
- Crypt of the NecroDancer is by Brace Yourself Games. This mod contains no game code or assets.
