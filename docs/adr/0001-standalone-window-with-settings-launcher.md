# 1. Standalone window with a Settings launcher

Date: 2026-11-06. Status: accepted.

## Context

The brief asks for integration with Settings, AddOns and for the preview to hide the Settings panel so the world is visible.

Building the full UI inside a Settings canvas means hiding `SettingsPanel` during every test. `SettingsPanel` is a Blizzard frame. Calling `HideUIPanel(SettingsPanel)` from addon code can taint it, and `Settings.OpenToCategory` is restricted on current clients, so GSM cannot reliably reopen it after a revert.

## Decision

- Settings, AddOns gets a small GSM canvas. It shows the current experience preset, preview state, and an Open button.
- The real UI is GSM's own movable window, opened by that button or `/gsm`.
- A test hides only GSM's window. Revert reopens it. GSM never reopens Blizzard's panel.
- Clicking Open hides `SettingsPanel` once, out of combat, so the two windows do not stack. That is a user click, not part of the preview.

## Consequences

- No Blizzard frame is touched during a preview, so the preview path has no taint risk from GSM.
- The UI is not limited by the canvas size.
- Two places to look: the canvas is only a launcher, and it says so.
- The in-game smoke test still has to confirm the Open click does not raise a protected-action error.
