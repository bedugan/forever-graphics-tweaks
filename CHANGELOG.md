# Changelog

## 0.1.0 (pre-release), 2026-11-06

First build. Complete and covered by automated tests, but not yet run in the Forever client. Every setting is marked unverified.

### Added

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

### Not included

- `SSAOType` and raid graphics CVars.
- Real screenshots.
- Applying a profile at login.
