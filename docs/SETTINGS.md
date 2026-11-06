# Settings

Every graphics setting FGT manages. This file is generated from `ForeverGraphicsTweaks/Core/Definitions.lua` by `scripts/settings_doc.lua`. Edit the definitions, then regenerate.

Nothing here is verified in the Forever client yet. Ranges and values come from the evidence listed for each setting. Impact is an estimate, not a measurement.

## How to read this

- **Range** is what FGT allows. The client may clamp further. FGT reads the value back after every write and reports a clamp.
- **Game default** is not listed. FGT reads it from the client at runtime with `C_CVar.GetCVarDefault`, because defaults can change between builds. The Default preset uses it.
- **Balanced** and **Ultra** are raw CVar values. "unchanged" means the preset leaves the setting alone.
- **Timing** is when the change shows on screen. None of these settings is documented as needing a reload or restart, so every one can use the 15 second test. The in-game checklist confirms this.
- Quality levels (tier 1) use the raw range 0 to 9. Blizzard and FGT show them as 1 to 10. Changing one rewrites the detailed values it controls, so FGT applies tier 1 first.

## Summary

| Setting | CVar | Range | Balanced | Ultra | Impact | Timing |
| --- | --- | --- | --- | --- | --- | --- |
| View distance level | `graphicsViewDistance` | 0 to 9 | 7 | 9 | high | immediate |
| Environment detail level | `graphicsEnvironmentDetail` | 0 to 9 | 7 | 9 | medium | immediate |
| Ground clutter level | `graphicsGroundClutter` | 0 to 9 | 7 | 9 | medium | delayed |
| Grass density | `groundEffectDensity` | 16 to 256, step 8 | 64 | 128 | medium | delayed |
| Grass draw distance | `groundEffectDist` | 40 to 500, step 10 | 320 | 450 | medium | delayed |
| Grass fade start | `groundEffectFade` | 40 to 500, step 10 | 280 | 400 | low | delayed |
| Object fade distance | `lodObjectFadeScale` | 50 to 300, step 10 | 150 | 200 | medium | immediate |
| Small object culling | `lodObjectCullSize` | 4 to 30 | 12 | 8 | medium | immediate |
| Terrain detail distance | `terrainLodDist` | 200 to 1500, step 25 | 650 | 1000 | medium | delayed |
| Horizon detail start | `horizonStart` | 400 to 6000, step 100 | unchanged | unchanged | medium | delayed |
| Always sharpen | `ResampleAlwaysSharpen` | 0 or 1 | 1 (on) | 1 (on) | low | immediate |
| Sharpness | `ResampleSharpness` | 0 to 2, step 0.1 | unchanged | unchanged | low | immediate |
| Texture filtering | `textureFilteringMode` | 0 to 5 | 4 (8x anisotropic) | 5 (16x anisotropic) | low | immediate |
| Water reflections | `reflectionMode` | 0 to 3 | unchanged | 3 | high | immediate |
| Shadow cascades | `shadowNumCascades` | 1 to 4 | unchanged | 4 | medium | immediate |
| Weather density | `weatherDensity` | 0 to 3 | unchanged | 3 | low | immediate |

## Not managed

- `SSAOType`: excluded. Its values are undocumented for this build, so FGT cannot validate them.
- Raid graphics mirrors (`RAID*`): left alone. `/fgt diag` reports whether raid settings are enabled.
- Resolution, graphics API, refresh rate, display device, and character models: out of scope.

## Quality levels

### View distance level

How far the world is drawn. Blizzard quality level. Changing it also resets the detailed values it controls, so FGT applies it first.

- CVar: `graphicsViewDistance`
- Range: 0 to 9
- Balanced: 7
- Ultra: 9
- Estimated impact: high
- Takes effect: Right away
- Evidence: Blizzard UI source, build 70790. Not verified in game

### Environment detail level

Detail of buildings, trees, and props. Blizzard quality level. Changing it also resets the detailed values it controls, so FGT applies it first.

- CVar: `graphicsEnvironmentDetail`
- Range: 0 to 9
- Balanced: 7
- Ultra: 9
- Estimated impact: medium
- Takes effect: Right away
- Evidence: Blizzard UI source, build 70790. Not verified in game

### Ground clutter level

Amount and reach of grass and small ground plants. Blizzard quality level. Changing it also resets the detailed values it controls, so FGT applies it first.

- CVar: `graphicsGroundClutter`
- Range: 0 to 9
- Balanced: 7
- Ultra: 9
- Estimated impact: medium
- Takes effect: As new terrain and ground cover load. Turn the camera or move a short way
- Evidence: Blizzard UI source, build 70790. Not verified in game

## Ground vegetation

### Grass density

How many grass and plant sprites are placed on the ground. Higher looks fuller and costs more.

- CVar: `groundEffectDensity`
- Range: 16 to 256, step 8
- Balanced: 64
- Ultra: 128
- Estimated impact: medium
- Takes effect: As new terrain and ground cover load. Turn the camera or move a short way
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

### Grass draw distance

Distance in yards at which grass stops being drawn.

- CVar: `groundEffectDist`
- Range: 40 to 500, step 10
- Balanced: 320
- Ultra: 450
- Estimated impact: medium
- Takes effect: As new terrain and ground cover load. Turn the camera or move a short way
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

### Grass fade start

Distance where grass starts fading out. Must not exceed grass draw distance.

- CVar: `groundEffectFade`
- Range: 40 to 500, step 10
- Constraint: must not exceed `groundEffectDist`
- Balanced: 280
- Ultra: 400
- Estimated impact: low
- Takes effect: As new terrain and ground cover load. Turn the camera or move a short way
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

## Object and terrain detail

### Object fade distance

Scales how far away trees, buildings, and props stay visible before fading. 100 is normal.

- CVar: `lodObjectFadeScale`
- Range: 50 to 300, step 10
- Balanced: 150
- Ultra: 200
- Estimated impact: medium
- Takes effect: Right away
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

### Small object culling

Objects smaller than this on screen get hidden. Lower values keep more small objects, so the slider runs right to left.

- CVar: `lodObjectCullSize`
- Range: 4 to 30
- Direction: lower values mean more detail, so FGT's slider runs right to left
- Balanced: 12
- Ultra: 8
- Estimated impact: medium
- Takes effect: Right away
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

### Terrain detail distance

Distance at which terrain switches to its simpler shape. Higher keeps hills and cliffs detailed further out.

- CVar: `terrainLodDist`
- Range: 200 to 1500, step 25
- Balanced: 650
- Ultra: 1000
- Estimated impact: medium
- Takes effect: As new terrain and ground cover load. Turn the camera or move a short way
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

### Horizon detail start

Where distant horizon terrain begins. Must stay below the horizon clip distance. No preset changes it.

- CVar: `horizonStart`
- Range: 400 to 6000, step 100
- Constraint: must stay below `horizonClip`
- Balanced: unchanged
- Ultra: unchanged
- Estimated impact: medium
- Takes effect: As new terrain and ground cover load. Turn the camera or move a short way
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

## Image quality

### Always sharpen

Applies the sharpening pass even at 100% render scale. Needed for Sharpness to have an effect without FSR.

- CVar: `ResampleAlwaysSharpen`
- Range: 0 or 1
- Balanced: 1 (on)
- Ultra: 1 (on)
- Estimated impact: low
- Takes effect: Right away
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

### Sharpness

Strength of the sharpening pass. 0 is strongest and 2 is weakest, so the slider runs right to left. Works with Always sharpen or FSR.

- CVar: `ResampleSharpness`
- Range: 0 to 2, step 0.1
- Direction: lower values mean more detail, so FGT's slider runs right to left
- Balanced: unchanged
- Ultra: unchanged
- Estimated impact: low
- Takes effect: Right away
- Evidence: Blizzard UI source, build 70790. Not verified in game

### Texture filtering

Keeps ground and wall textures crisp at steep viewing angles.

- CVar: `textureFilteringMode`
- Range: 0 to 5
- Values: 0 Bilinear, 1 Trilinear, 2 2x anisotropic, 3 4x anisotropic, 4 8x anisotropic, 5 16x anisotropic
- Balanced: 4 (8x anisotropic)
- Ultra: 5 (16x anisotropic)
- Estimated impact: low
- Takes effect: Right away
- Evidence: Blizzard UI source, build 70790. Not verified in game

### Water reflections

How much of the world water reflects. Higher reflects more and costs the most of any setting here.

- CVar: `reflectionMode`
- Range: 0 to 3
- Balanced: unchanged
- Ultra: 3
- Estimated impact: high
- Takes effect: Right away
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

## Other enhancements

### Shadow cascades

Number of shadow detail bands. More bands keep distant shadows sharper. Blizzard's shadow quality setting can reset this.

- CVar: `shadowNumCascades`
- Range: 1 to 4
- Balanced: unchanged
- Ultra: 4
- Estimated impact: medium
- Takes effect: Right away
- Evidence: warcraft.wiki.gg (Retail). Not verified in game

### Weather density

Amount of rain and snow particles. Only visible in zones with active weather.

- CVar: `weatherDensity`
- Range: 0 to 3
- Balanced: unchanged
- Ultra: 3
- Estimated impact: low
- Takes effect: Right away
- Evidence: warcraft.wiki.gg (Retail). Not verified in game
