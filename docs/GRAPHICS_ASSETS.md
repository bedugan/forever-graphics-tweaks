# Graphics assets

How to add real in-game screenshots to the comparison panel. GSM 0.1.0 ships none. Every setting shows a Lua-drawn schematic labeled "Schematic illustration, not an in-game screenshot." (ADR 0005).

The rule is simple. An image goes in the manifest only if it was captured in the Forever client with the setting at the stated value. Never label an edited, upscaled, or generated image as an in-game screenshot.

## What a set looks like

One set is three images of the same scene, same camera, same time of day and weather, with only one CVar changed:

- Low: near the bottom of GSM's range
- Medium: the middle
- High: near the top

The panel's example line shows which value GSM treats as each level. Use those values.

## Capture

1. Pick a scene where the setting is easy to see. Suggestions:

   | Setting | Scene |
   | --- | --- |
   | Grass density, distance, fade | Flat grassland, for example Elwynn Forest fields |
   | Object fade, small object culling | A town with trees and props in the distance |
   | Terrain detail, horizon | A high ridge looking over hills |
   | Texture filtering, sharpness | A cobbled road at a shallow angle |
   | Water reflections | A lake with trees on the shore |
   | Shadow cascades | Trees or buildings casting shadows into the distance |
   | Weather density | A zone with active rain or snow |

2. Set every other graphics setting to a fixed level and leave it there for the whole set.
3. Stand still, dismount, and face the scene. Keep the camera fixed between shots. One way is a saved camera view with macros, `/run SaveView(5)` and `/run SetView(5)`. This is not yet verified on Forever. If it does not work, do not touch the mouse between shots.
4. Hide the UI with Alt+Z.
5. Change only the one CVar with GSM's Test settings and Keep, or with `/console <cvar> <value>`. Wait a few seconds, or turn the camera away and back, for delayed settings to load.
6. Take the screenshot with Print Screen. Files land in `_forever_/Screenshots`.
7. Write down the build from `/gsm diag`, the zone, and the three values.

## Prepare

The client loads TGA and BLP. GSM uses TGA:

- 32-bit (RGBA), uncompressed
- Power-of-two sides. The panel is about 390 by 140 pixels, so use 512 by 256
- File names: `<cvar>_low.tga`, `<cvar>_medium.tga`, `<cvar>_high.tga`

With ImageMagick:

```sh
magick input.jpg -resize 512x256^ -gravity center -extent 512x256 \
  -alpha on -compress none output.tga
```

Crop the same way for all three images in a set so the frame lines up.

Add the annotation (arrow, ring, or label) in an image editor before converting. Mark the area that changes, in the same place in all three images. Keep it small so it does not hide the change.

## Add to the manifest

Copy the files to `GraphicsSettingsManager/Media/`. Then add an entry to `GraphicsSettingsManager/Media/Manifest.lua`:

```lua
ns.Manifest = {
    groundEffectDensity = {
        build = "1.60.1.70790",
        low = "Interface\\AddOns\\GraphicsSettingsManager\\Media\\groundEffectDensity_low",
        medium = "Interface\\AddOns\\GraphicsSettingsManager\\Media\\groundEffectDensity_medium",
        high = "Interface\\AddOns\\GraphicsSettingsManager\\Media\\groundEffectDensity_high",
        note = "Elwynn Forest, fixed camera, only this CVar changed.",
    },
}
```

Paths leave off the `.tga` extension. A level with no path falls back to the schematic, so a partial set still works.

Then:

1. `/reload` is not enough for new files. Restart the client.
2. Open GSM, select the setting, and click each level. The caption should say "In-game screenshot" with the build.
3. Run in-game check 5.3 in [TESTING.md](TESTING.md).
4. Commit the images and manifest together. Say in the commit message where and on which build they were captured.
