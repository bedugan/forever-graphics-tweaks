# Testing

FGT has two kinds of tests. Automated tests run the Lua code outside the game against a fake client. The in-game checklist covers what only the real Forever client can show.

A passing automated test says the logic is right against the fake client. It says nothing about how the real client behaves. Every row in the in-game checklist stays "Not run" until someone runs it in the game and records what they saw.

## Automated tests

Run them with:

```sh
scripts/test.sh
```

The script starts a Lua 5.1 container (Docker, or Colima's containerd through `colima nerdctl`). Lua 5.1 is the version WoW embeds. It:

1. Runs `luac -p` on every addon and test file.
2. Runs `tests/run.lua`, which loads the addon against fakes in `tests/mocks.lua`.
3. Checks that `docs/SETTINGS.md` matches `Core/Definitions.lua`.

### What they cover

| File | Covers |
| --- | --- |
| `test_cvarstore.lua` | Readback results (ok, rejected, clamped, error), missing and restricted CVars, tier order, rollback after a partial failure |
| `test_experience.lua` | Classic, Enhanced, and Unknown detection, including a missing API, an API error, nil, and unexpected values. The warning shows once per session and again when the preset changes |
| `test_pending.lua` | Pending edits never write. Presets fill pending values. Custom keeps manual edits. Validation of ranges and the grass fade and horizon constraints |
| `test_preview.lua` | 15 second countdown from elapsed time, not frames. Keep, manual Revert, timeout, and logout. Revert restores the exact snapshot and skips values something else changed. Partial apply failures roll back. Combat and empty tests are refused |
| `test_profiles.lua` | Baseline captured on first write only. Restore Original. Profile save, load, delete, and name rules. Loading a profile writes nothing |
| `test_definitions.lua` | Every definition is complete and its preset values are in range and on step. `SSAOType` is not managed. Loading Core writes nothing. Diagnostics is read-only |
| `test_ui_smoke.lua` | Loads every file in TOC order against a fake frame API, then clicks through the window, presets, Test, the overlay, Keep, Revert, timeout, keyboard and gamepad keys, the Classic warning, combat, profiles, Restore Original, the Settings launcher, and every comparison panel |

### Latest result

| Date | Commit | Result |
| --- | --- | --- |
| 2026-11-06 | `feat/m1-m5-prototype` | 70 passed, 0 failed |

### What the fakes cannot tell us

- Whether Forever accepts each CVar, its real range, or how it clamps.
- Whether quality-level CVars rewrite their children the way the fake does.
- Layout, fonts, textures, and how things look at different UI scales.
- Taint, protected-action errors, and keyboard or gamepad focus.
- SavedVariables persistence.

## In-game checklist

Run this on the Forever client with only FGT and BugSack enabled. BugSack catches Lua errors and "action blocked" messages that the default UI can hide. Record the client build from `/fgt diag` with each run.

Status values: Not run, Pass, Fail (link an issue), Blocked.

Before starting, write down your own values for a few settings (`/fgt diag` prints them). The restore checks need a known starting point that is not the game default.

### M1: Foundation and compatibility

| # | Check | Steps | Expected | Status |
| --- | --- | --- | --- | --- |
| 1.1 | Fresh install loads | Install the ZIP, start the game, log in | No Lua errors. FGT is listed in the AddOns menu at character select | Not run |
| 1.2 | No writes at login | Compare `/fgt diag` values before and after a login | Values unchanged | Not run |
| 1.3 | Build detection | `/fgt diag` | Shows the client version, build, and interface 16001 | Not run |
| 1.4 | Settings entry | Esc, Options, AddOns, Forever Graphics Tweaks | Launcher canvas shows experience and test status | Not run |
| 1.5 | Open from Settings | Click Open on the launcher | Settings closes, FGT window opens, no "action blocked" error | Not run |
| 1.6 | Slash command | `/fgt`, then `/fgt` again | Window opens, then closes | Not run |
| 1.7 | CVar status | `/fgt diag` | Each setting is available, missing, or restricted. Note any that are not available | Not run |

### Experience detection

| # | Check | Steps | Expected | Status |
| --- | --- | --- | --- | --- |
| 2.1 | Classic | On a Classic experience character, open `/fgt` | Header says Classic. Warning banner with Continue and Cancel. Test is disabled | Not run |
| 2.2 | Continue | Click Continue, close, reopen | Banner gone and stays gone this session | Not run |
| 2.3 | Cancel | Fresh session, open, click Cancel | Window closes. Nothing changed | Not run |
| 2.4 | Enhanced | On an Enhanced character, open `/fgt` | Header says Enhanced. No banner | Not run |
| 2.5 | Preset untouched | After any test, check the game's experience setting | Unchanged | Not run |
| 2.6 | Unknown | Only if the API is ever missing | Header says Unknown with a reason. No guess | Not run |

### M2: Safe preview

Start with one setting, Texture filtering, before testing presets.

| # | Check | Steps | Expected | Status |
| --- | --- | --- | --- | --- |
| 3.1 | Pending only | Change Texture filtering in FGT | Pending column shows the new value. `/fgt diag` shows the old live value | Not run |
| 3.2 | Test hides FGT | Click Test settings | FGT window hides. Overlay shows with a countdown from 15. No Lua error | Not run |
| 3.3 | Keep | Click Keep settings | Overlay closes, window stays closed, value stays after 20 seconds | Not run |
| 3.4 | Manual revert | Test again, click Revert | Old value back. FGT window reopens with the pending value still set | Not run |
| 3.5 | Timeout | Test again, wait | At 0 the old value comes back and the window reopens | Not run |
| 3.6 | Keyboard | Test, press Enter. Test, press Esc | Enter keeps, Esc reverts. Esc does not also open the game menu | Not run |
| 3.7 | Other keys pass through | Test, then move with WASD | Character moves. Countdown keeps going | Not run |
| 3.8 | Hidden UI | Test, press Alt+Z, wait 15 seconds, press Alt+Z | The timeout still reverted | Not run |
| 3.9 | Overlay moves | Drag the overlay, test again later | Opens where you left it | Not run |
| 3.10 | `/fgt revert` | Test, type `/fgt revert` | Reverts | Not run |
| 3.11 | Clamping | Pick a value the client may cap, test it | If the client adjusts it, chat says what you asked for and what you got | Not run |

### M3: Settings and presets

| # | Check | Steps | Expected | Status |
| --- | --- | --- | --- | --- |
| 4.1 | Balanced | Click Balanced, Test, Keep | Values match `docs/SETTINGS.md`. Note visible changes and FPS | Not run |
| 4.2 | Ultra | Same with Ultra | Same, note FPS | Not run |
| 4.3 | Default | Same with Default | Values match the client defaults shown in the detail pane | Not run |
| 4.4 | Custom | Edit a slider after a preset, pick Balanced, then Custom | Your edit comes back | Not run |
| 4.5 | Each setting | For every setting, test Low and High in a busy outdoor zone | The described change is visible. Note timing. Record findings in `docs/SETTINGS.md` | Not run |
| 4.6 | Delayed settings | Test grass density, turn the camera | Change appears as the ground reloads. Overlay hint mentions it | Not run |
| 4.7 | Quality parents | Test View distance level with Terrain detail distance pending | Terrain detail distance ends at the pending value, not the one the parent set | Not run |
| 4.8 | Restore original | Keep Ultra, click Restore original, confirm | Your own pre-FGT values come back, not game defaults | Not run |
| 4.9 | Restore asks first | Click Restore original, then Cancel | Nothing changes | Not run |
| 4.10 | Blizzard panel change | Keep Ultra, move a Blizzard graphics slider | FGT does not change it back later | Not run |

### M4: Visual comparisons

| # | Check | Steps | Expected | Status |
| --- | --- | --- | --- | --- |
| 5.1 | Schematics | Select each setting, click Low, Medium, High | A drawing appears with a callout and the caption "Schematic illustration, not an in-game screenshot." | Not run |
| 5.2 | Example values | Same | The example line shows a value for each level | Not run |
| 5.3 | Screenshot slot | Only after real screenshots are added | Image shows with the "In-game screenshot" caption and build | Not run |

### M5: Profiles, persistence, and polish

| # | Check | Steps | Expected | Status |
| --- | --- | --- | --- | --- |
| 6.1 | Save profile | Profiles, type "Mac Balanced", Save | Listed | Not run |
| 6.2 | Load profile | Discard, load the profile | Pending values fill. Nothing changes until Test | Not run |
| 6.3 | Reload persistence | `/reload`, `/fgt diag` | Load counter went up by one. Profiles and baseline still there | Not run |
| 6.4 | Restart persistence | Quit the game normally, start again | Same as 6.3 | Not run |
| 6.5 | Logout during test | Test, then `/reload` before the timer ends | After reload the old values are live | Not run |
| 6.6 | Combat | Open FGT, enter combat | Window closes. `/fgt` refuses in combat. Test refuses in combat | Not run |
| 6.7 | Combat during test | Test, then enter combat | Overlay buttons still work with the mouse. Timeout still reverts | Not run |
| 6.8 | UI scale | Set UI scale to the smallest and largest, open FGT | Window fits, text readable, nothing overlaps | Not run |
| 6.9 | Keyboard in window | Arrows to move and adjust, Enter to test | Works. Other keys still reach the game | Not run |
| 6.10 | Controller | With gamepad mode on, use the D-pad, A, and B in the window and overlay | D-pad moves and adjusts, A tests or keeps, B closes or reverts | Not run |
| 6.11 | Arbitrary starting values | Set odd values with Blizzard's panel first, then use FGT and Restore original | Your odd values come back | Not run |

### Run log

| Date | Build | Tester | Checks run | Notes |
| --- | --- | --- | --- | --- |
| | | | | |
