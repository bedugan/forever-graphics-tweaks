# 7. Capture companion addon and a cropping import

Date: 2026-11-06. Status: accepted.

## Context

ADR 0005 left real screenshots to a manual process: set one CVar, hide the UI, press Print Screen, repeat three times per setting, then crop and convert by hand. For 16 settings that is about 50 careful shots plus image editing, so it would likely never get done.

Addons can call `Screenshot()`, write CVars, and hide the UI. So the game can take the shots, and a script can do the cropping.

Three choices came up:

1. Build capture into GSM, ship it as a separate addon, or ship it as a library other addon authors can use.
2. Crop by hand, crop at a fixed position, or find the change automatically.
3. Decide how a shot sets its value: from the last shot, or from a fixed starting point.

## Decision

**A companion addon now, a library later.** `GraphicsSettingsManager_Capture` depends on GSM and stays out of the release ZIP. Players never load code that takes screenshots and rewrites settings in a loop. Its `Runner.lua` and `Band.lua` know nothing about GSM, so they can become a library once a second user exists.

**GSM gets a small public API.** `GraphicsSettingsManagerAPI` exposes the setting definitions, level values, status, and `set` and `restore`. `set` goes through the same checks and readback as a preview, and it captures the baseline first, so Restore original still works after a capture. The companion never calls `C_CVar.SetCVar` itself.

**Every shot starts from the same snapshot.** Before each shot the companion restores the values from before the run, then changes one setting. One shot never leaks into the next. Each setting gets Low, Medium, High, then Low again as a control.

**The import finds the change.** `scripts/import_captures.sh` runs Python with Pillow and NumPy in a container. It measures where the three levels differ, subtracts what differs between Low and the control, and picks the smallest crop at the panel's shape that holds 70% of the change. It also draws a focus box in the panel when the change is small. A JSON override file covers the cases it gets wrong, and a review page makes every crop easy to check before commit.

**Textures stay TGA.** 512 by 256, with the picture in the top 184 rows so the panel shows it at its 390 by 140 shape through texture coordinates.

## Consequences

- Capturing one setting takes about 15 to 25 seconds of standing still, and a human only checks the review page. The first in-game session (2026-11-07) used a 6 second wait for background settings, which felt too long, so it is now 3.
- Nothing locks the camera. If the player moves it during a run, the shots are wasted. The import cannot tell, apart from a large control difference.
- `SetUIVisibility`, `SetPropagateKeyboardInput`, and `Screenshot()` are unverified on Forever. The companion falls back to asking for Alt+Z.
- The import needs Docker or Colima, the same as the Lua tests.
- Uncompressed TGAs make the ZIP grow by about 1.2 MB per setting. BLP conversion is a follow-up if that matters.
- GSM now has a public API. Changing it can break the companion, so both live in this repo and share tests.
