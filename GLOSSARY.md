# Glossary

Terms used in code, docs, and issues for Forever Graphics Tweaks (FGT).

## Settings and values

- **Setting**: one entry in `Core/Definitions.lua`. It maps to exactly one CVar and carries its label, range, preset values, timing, and evidence.
- **CVar**: a client console variable read and written through `C_CVar`. FGT only touches CVars listed in Definitions.
- **Live value**: what `C_CVar.GetCVar` returns right now.
- **Pending value**: a value the user picked in the FGT window that has not been applied. Pending values never change the game.
- **Native default**: what `C_CVar.GetCVarDefault` returns for a CVar. The Default preset uses these at runtime. FGT never hard-codes them.
- **Baseline**: the live values FGT captured the first time it wrote any CVar. Restore Original puts these back. Not the same as native defaults.
- **Tier**: apply order. Tier 1 is Blizzard's quality-level parents (`graphicsViewDistance`, `graphicsEnvironmentDetail`, `graphicsGroundClutter`). Tier 2 is everything else. Parents go first because changing a parent rewrites its children.
- **Status**: how a CVar looks on this client. `available`, `missing` (the client does not know it), or `restricted` (read-only, secure, or locked).
- **Write result**: what readback showed after a write. `ok`, `clamped` (the client stored a different value), `rejected` (value unchanged), or `error` (the call threw).
- **Unverified**: a setting whose range, default, or effect nobody has confirmed in the Forever client yet. Every setting in 0.1.0 is unverified.

## Presets and profiles

- **Preset**: Default, Balanced, Ultra, or Custom. Picking a preset fills pending values. It does not apply them.
- **Custom**: shown when pending values match no other preset.
- **Profile**: a named set of values the user saved, such as "Mac Balanced". Loading a profile fills pending values. Profiles never apply at login.

## Preview

- **Preview** (or **test**): a timed trial of pending values. FGT snapshots, validates, applies, reads back, then shows the countdown overlay.
- **Snapshot**: the live values of every CVar the preview will change, captured just before applying.
- **Journal**: a copy of the snapshot written to SavedVariables before applying, so an interrupted preview can be detected on the next load.
- **Keep**: accept the previewed values. They become the live configuration.
- **Revert**: put the snapshot back. Timeout means Revert.
- **Restore Original**: put the baseline back, after a confirmation. Different from Revert.
- **Overlay**: the small movable countdown frame shown during a preview.
- **Previewable**: a setting whose change and reversal both work while the game runs. Settings that are not previewable cannot be part of a timed test.

## Experience

- **Experience preset**: the Forever account choice between Classic and Enhanced presentation, read from `C_GameRules.GetForeverExperiencePreset()`.
- **Classic** = `Enum.ForeverExperiencePreset.Classic` (0). **Enhanced** = `Enum.ForeverExperiencePreset.Enhanced` (1). **Unknown** means the API is missing, errored, or returned something else. FGT reads this and never writes it.

## Visuals

- **Comparison**: the Low, Medium, High panel for one setting.
- **Schematic**: a Lua-drawn diagram labeled as an illustration, used when no real screenshot exists.
- **Manifest**: `Media/Manifest.lua`, which lists packaged screenshots per setting and level.
