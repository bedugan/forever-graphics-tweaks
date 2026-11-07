# Graphics assets

How real in-game screenshots get into the comparison panel. Until a setting has them, it shows a Lua-drawn schematic labeled "Schematic illustration, not an in-game screenshot." (ADR 0005).

The rule: an image goes in the manifest only if the Forever client captured it with the setting at the stated value. Never label an edited, upscaled, or generated image as an in-game screenshot. Cropping and scaling down a real shot is fine.

The pipeline has two halves (ADR 0007):

1. **Capture, in the game.** The companion addon `GraphicsSettingsManager_Capture` hides the interface, sets each setting to Low, Medium, and High, and takes a screenshot of each with a caption band at the bottom. It logs every shot to SavedVariables.
2. **Import, on the Mac.** `scripts/import_captures.sh` matches the log to the screenshot files, finds where the picture changed, crops that area at the panel's shape, and writes the textures and `Media/Manifest.lua`.

## What a set looks like

One set is four screenshots of the same scene from the same camera. Only one setting changes:

| Shot | Value |
| --- | --- |
| Low | Bottom of GSM's range |
| Medium | Middle |
| High | Top |
| Control | Low again |

Before each shot the companion puts every managed setting back to how it was before the run, then changes the one setting. A quality level (view distance, environment detail, ground clutter) still rewrites its own children, because that is what the level does in the game.

The control shot catches things that move on their own, such as water, weather, and NPCs. The import ignores any area that differs between the two Low shots.

## Install the companion

The companion is a developer tool. It is not in the release ZIP.

1. Quit the game.
2. Copy or symlink `GraphicsSettingsManager_Capture` from this repo into `_forever_/Interface/AddOns/`, next to `GraphicsSettingsManager`.
3. Start the game and enable both addons on the character screen.

On SteamOS, move the folder with Syncthing, the same way as the main addon.

## Capture

1. Set the game's screenshot format to PNG or TGA if you can (`/console screenshotFormat png`). JPEG adds noise that the import has to look past. The companion records the format but does not change it.
2. Pick a scene where the setting is easy to see:

   | Setting | Scene |
   | --- | --- |
   | Grass density, distance, fade | Flat grassland, for example Elwynn Forest fields |
   | Object fade, small object culling | A town with trees and props in the distance |
   | Terrain detail, horizon | A high ridge looking over hills |
   | Texture filtering, sharpness | A cobbled road at a shallow angle |
   | Water reflections | A lake with trees on the shore |
   | Shadow cascades | Trees or buildings casting shadows into the distance |
   | Weather density | A zone with active rain or snow |

3. Dismount, stand still, and set the camera. Nothing can lock the camera, so do not touch the mouse or keys until the run ends.
4. Type `/gsmcap <cvar>` for one or more settings, for example `/gsmcap groundEffectDensity groundEffectDist`. `/gsmcap all` runs every setting that can be tested. The chat line says how long it will take.
5. The companion hides the interface. If the game does not allow that, press Alt+Z when asked. The run starts once the interface is hidden.
6. Wait. Each setting takes 4 shots. The companion waits 2 seconds after an instant change and 3 seconds after one that loads in the background, plus the time the game takes to save each file.
7. When it says "Done", press Alt+Z if the interface is still hidden, then `/reload`. The game writes the log only on reload or logout.

The companion checks every level before it starts. If one would break a GSM limit, it drops that setting and says why in chat, rather than shooting a partial set. Grass fade start must not exceed grass draw distance. So before capturing grass draw distance, set grass fade start to 40 with GSM. Before capturing grass fade start, set grass draw distance to 500. A shot that still fails during the run is skipped, and chat names it.

The run stops and puts every setting back if you press Esc, move, enter combat, hit a loading screen, or log out. `/gsmcap stop` does the same.

| Command | Does |
| --- | --- |
| `/gsmcap help` | Lists the commands |
| `/gsmcap list` | Shows each setting, its status, and its Low, Medium, and High values |
| `/gsmcap <cvar> ...` | Captures those settings |
| `/gsmcap all` | Captures every setting that can be tested on this client |
| `/gsmcap stop` | Stops and puts the settings back |

## Import

```sh
scripts/import_captures.sh
```

It needs Docker or Colima. The first run builds a small Python image. Options:

| Option | Use |
| --- | --- |
| `--wow DIR` | The `_forever_` folder. Defaults to `/Applications/World of Warcraft/_forever_` |
| `--log FILE --screens DIR` | Point at a capture log and screenshot folder directly, for example a Syncthing folder from a SteamOS machine |
| `--run N` | Import only this run. Without it, each setting comes from the newest run that has its Low, Medium, and High shots, so you can capture several scenes in one session and import once |
| `--only cvar,cvar` | Import only these settings |
| `--manifest-only` | Rebuild `Media/Manifest.lua` from `assets/screenshots.json` without new shots |
| `--test` | Run the import's own tests |

The script only reads the WoW folders. It copies the log and that day's screenshots into `.capture/in` (ignored by git), and the container sees only this repo.

For each setting it:

1. Matches each logged shot to the nearest screenshot file from 5 seconds before it to 1 second after. The file name is the time of the request, and the log entry is written once the game has saved the file, which takes a few seconds for a large PNG.
2. Cuts off the caption band.
3. Builds a change map: how much each area differs between Low, Medium, and High, minus anything that also differs between Low and the control.
4. Picks the smallest crop, at the panel's 390 by 140 shape, that holds 70% of the change. The crop is never narrower than 512 screen pixels, so nothing gets scaled up.
5. Draws a focus box around the middle 80% of the change, unless the change already fills most of the crop.
6. Writes `Media/Shots/<cvar>_<level>.tga` (512 by 256, the picture in the top 512 by 184), `assets/screenshots.json`, and `Media/Manifest.lua`.
7. Writes `.capture/review.html`, which shows each full frame with the crop marked, the change map, and the three panel views.

It reports missing shots, a missing control, size mismatches, settings the client clamped to the same value at two levels, and settings with no complete set in any run, with the reason the companion logged.

## Review

Open `.capture/review.html` and check every setting:

- The crop shows the thing the setting changes.
- The focus box, if any, sits on the change.
- The three levels look different. If they do not, the setting may need a different scene, or it may not work on Forever. Note that in an issue.

To fix a crop by hand, add it to `assets/screenshots-overrides.json` and run the import again:

```json
{
  "groundEffectDensity": {
    "crop": [0.62, 0.30, 0.35],
    "focus": null,
    "note": "Elwynn Forest, north of Goldshire. Fixed camera, only this setting changed."
  }
}
```

- `crop` is the center x, center y, and width, each as a fraction of the picture without the band. The height follows from the panel shape.
- `focus` is x, y, width, and height as fractions of the crop, from the top left. `null` turns the box off. Leave it out to keep the computed one.
- `note` replaces the default caption, which is the zone plus "Fixed camera, only this setting changed."

## Check and commit

1. Restart the client. `/reload` does not load new texture files.
2. Open GSM, select the setting, and click each level. The caption should say "In-game screenshot" with the build, and the example line should show the value in that shot.
3. Run in-game check 5.3 in [TESTING.md](TESTING.md).
4. Commit the TGAs, `assets/screenshots.json`, any overrides, and `Media/Manifest.lua` together. Say where and on which build they were captured.

## Size

Each TGA is about 390 KB, so three per setting for all 16 settings comes to about 19 MB. That is fine for a first set. Converting to BLP would cut it a lot and is a possible follow-up.
