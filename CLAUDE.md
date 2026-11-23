# Crypt of the NecroDancer access project (Crypt Access)

This folder is a mod that makes Crypt of the NecroDancer playable by fully blind players. It was set up
with the game-access-kit plugin. Its memory is `NOTEBOOK.md`, in this folder. Methodology:
`C:\Users\Nitropc\code\mods\starting_points\template_roguelike.md` and `template_generic.md` (rules 0.x apply).
Sibling project with a proven rhythm-cue design: `C:\Users\Nitropc\code\mods\rodn` (Rift Access).

## Player

- Level: modder who directs the work; Claude writes all the code. Be concise and technical, name files and functions.
- Language: English. Always reply in this language, whatever language the plugin's instructions are written in.
- Screen reader: NVDA assumed (not confirmed). The mod speaks through Prism, so JAWS, Narrator and SAPI fallback also work.
- The end users are fully blind players: every screen and every gameplay fact must reach them through speech or sound.

## Talking to the player

The player reads everything through a screen reader, which reads text in a straight line with no way to skim:

- Lists and short paragraphs. No Markdown tables, ASCII art or decorative symbols: use nested bullet lists.
- Lead with the answer or the result, then the detail.
- A command or text the player must copy goes alone in a code block, nothing else on its lines.
- Each decision goes through AskUserQuestion, recommended option first and marked (Recommended).
- Warn explicitly whenever a tool call or action is blocked or denied (user request, 2026-11-23).

## How we work

- **Explain, then ask** before any action that changes the game folder, installs or downloads anything, or edits
  system settings. Reading, searching the web, and editing or building inside this project folder need no permission.
  Downloads from official sources (GitHub releases of the tool's own repo, vendor sites) are allowed (user, 2026-11-23).
- **The player is the only human tester.** Group changes so one test checks as much as possible, and say exactly what
  to do in the game and what they should hear. Read the logs yourself (NecroDancer.log, CryptAccess speech log).
- **Facts come from sources.** Never write a game function, field, event or file path you have not found in the
  decompiled source (`game/src`), the extracted packages (`game/base`, `game/dlc`), the docs, or a log. Anything
  unproven is marked HYPOTHESIS in the notebook.
- **Game updates break mods.** The notebook records the game build the mod was proven on. After a game update,
  re-run `tools/extract_game.ps1`, re-check the config patch and the hooks first.

## Notebook rules

`NOTEBOOK.md` carries the project from one session to the next.

- Read it at the start of every task.
- Before ending a task, update it: stage status, new proven facts (each with how it was proven), decisions, pitfalls
  met, and one line in the test log per in-game test.
- Replace stale lines rather than adding new ones on top: the notebook describes the project as it is now.
