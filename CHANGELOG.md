# Changelog

## 0.1.0 (beta), 2026-11-07

First beta for Forever 1.60.1. Automated tests pass. Keep, Revert, the timeout, Restore original, and profile persistence after a client restart passed owner testing. The full in-game checklist remains in progress.

### Added

- In-game screenshots for 11 settings, captured on Forever 1.60.1 (70790). Ten were taken at 100% render scale. Small object culling comes from an earlier session at 50%, which showed the change more clearly. Grass fade start, texture filtering, Sharpness, Always sharpen, and weather density keep their schematics.
- 16 graphics settings in five groups, defined in one file (`Core/Definitions.lua`).
- Default, Balanced, Ultra, and Custom presets. Default reads the client's own defaults.
- Pending values that change nothing until you test.
- A 15 second test with Keep and Revert. Applies quality levels first, reads every value back, rolls back a partial failure, and reverts on timeout, `/gsm revert`, or logout.
- Restore original, which puts back the settings from before GSM's first change, after a confirmation.
- Named profiles that load into pending values only.
- Classic, Enhanced, and Unknown experience detection, with a once-per-session warning for Classic.
- Low, Medium, High comparison panel with labeled schematic drawings and slots for real screenshots.
- Settings, AddOns launcher and the `/gsm` command, with `/gsm diag` for a read-only report.
- Keyboard and gamepad controls for the window and the test overlay.
- Lua 5.1 tests for the core and a UI smoke test, run with `scripts/test.sh`.

### Changed

- Balanced is now the best-value preset. It changes only grass density (64), grass draw distance (270) and fade start (230), object fade distance (150), and shadow cascades (3). Quality levels, small object culling, terrain detail distance, Always sharpen, and texture filtering stay as they are, because the screenshots showed little or no gain over the game's defaults. See ADR 0008.
- `/gsmcap` waits 3 seconds after a background setting, down from 6.
- `/gsmcap` checks every level before it starts. A setting that would break a GSM limit is dropped with a reason in chat, instead of skipping shots silently.
- The capture import takes each setting from the newest run with a complete set, so one import covers a whole session, and it matches files saved up to 5 seconds before their log entry.
- `/gsmcap` refuses to start when render scale is below 100%, because the shots would be blurred.
- `GraphicsSettingsManagerAPI.check` says why `set` would refuse a value, without writing it.

### Added for developers

- `GraphicsSettingsManager_Capture`, a companion addon not in the release ZIP. `/gsmcap` sets each setting to Low, Medium, and High plus a control shot, takes screenshots with a caption band, and puts everything back.
- `scripts/import_captures.sh`, which finds where each setting changed the picture, crops that area at the panel's shape, and writes the textures, the manifest, and a review page.
- `GraphicsSettingsManagerAPI`, a small public API the companion uses to read definitions and write one setting with readback.
- The comparison panel shows the value used in each screenshot and an optional focus box.

### Not included

- `SSAOType` and raid graphics CVars.
- Applying a profile at login.
