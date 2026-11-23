# Crypt Access

Crypt Access makes Crypt of the NecroDancer (Steam, Synchrony version 4.2) playable without sight. It speaks
through your screen reader (NVDA, JAWS, Narrator, or Windows speech when no screen reader runs) and adds
positional sounds for enemies, items, walls and exits.

## Install

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

## Settings

In the game: Options, Mod settings, Crypt Access. There you can turn the enemy, item and wall sounds on or
off, set their range and volume, add a metronome tick, freeze automatically at the start of each floor,
and choose whether hits on enemies and menu positions are spoken.

## Credits and licences

- Speech through Prism; its licences are in `CryptAccess\licenses`.
- Crypt of the NecroDancer is by Brace Yourself Games. This mod contains no game code or assets.
