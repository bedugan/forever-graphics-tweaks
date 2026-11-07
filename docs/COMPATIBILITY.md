# Compatibility

What GSM relies on, where each fact came from, and what still needs testing inside the game.

## Target

| Item | Value | Evidence |
| --- | --- | --- |
| Game | World of Warcraft: Forever (Camelot) | Brief |
| Build | 1.60.1.70790 | wow-ui-source `forever` branch, commit `eac30af` |
| Interface | 16001 | Brief, forever-addon-kit TOC |
| API family | Retail (Mainline) | UI source uses `C_CVar`, `Settings`, `C_GameRules` |

## Evidence levels

- **Source**: read in Blizzard's UI source for the target build. Documented, not observed.
- **Wiki**: from warcraft.wiki.gg, usually describing Retail. Weaker than Source.
- **In-game**: observed in the Forever client. Nothing in 0.1.0 is at this level yet.

## APIs

| API | Use in GSM | Evidence | In-game |
| --- | --- | --- | --- |
| `C_CVar.GetCVar(name)` | Read live values | Source | Pending |
| `C_CVar.GetCVarDefault(name)` | Default preset | Source | Pending |
| `C_CVar.GetCVarInfo(name)` | Detect missing, read-only, secure, locked | Source. Returns value, default, two storage flags, `isLockedFromUser`, `isSecure`, `isReadOnly` | Pending |
| `C_CVar.SetCVar(name, value)` | Apply | Source. Returns `success`. Requires a valid public, non-read-only, non-secure CVar | Pending |
| `C_CVar.SetTempCVar` / `RemoveTempCVar` | Not used | Source lists them. Semantics undocumented. Tracked as an issue | Pending |
| `C_GameRules.GetForeverExperiencePreset()` | Experience detection | Source. Nilable return | Pending |
| `Enum.ForeverExperiencePreset` | Classic = 0, Enhanced = 1 | Source | Pending |
| `Settings.RegisterCanvasLayoutCategory`, `Settings.RegisterAddOnCategory` | Launcher canvas | Source | Pending |
| `Settings.OpenToCategory` | Not used | Restricted for addons on current clients | n/a |
| `HideUIPanel(SettingsPanel)` | Only on the launcher's Open click, out of combat | Source. Taint risk, see ADR 0001 | Pending |
| `ReloadUI` | Never called | Protected on Forever | n/a |
| `GetTime` | Preview clock | Source | Pending |
| `GetBuildInfo` | Diagnostics | Source | Pending |
| `UISpecialFrames` | Esc closes the GSM window | Source | Pending |
| `EnableGamePadButton`, `OnGamePadButtonDown` | Controller Keep and Revert on the overlay | Source | Pending |

## SavedVariables

- `GraphicsSettingsManagerDB` holds the baseline, profiles, window position, and a load counter.
- Early Forever beta builds had reports of SavedVariables not loading. Not verified on 70790. `/gsm diag` shows the load counter. If it stays at 1 after a reload, persistence is broken.

## Textures

- GSM 0.1.0 ships no image files. Schematics use `SetColorTexture` and `CreateLine`.
- For future screenshots: TGA, 32-bit, power-of-two sides (for example 512 by 256). BLP also works. PNG support is not verified on Forever, so GSM does not rely on it.

## CVars

Per-setting detail is in [SETTINGS.md](SETTINGS.md). Summary:

| CVar | In UI source | Notes |
| --- | --- | --- |
| `graphicsViewDistance`, `graphicsEnvironmentDetail`, `graphicsGroundClutter` | Yes | Range 0 to 9 (Blizzard shows 1 to 10). Tier 1 parents |
| `textureFilteringMode` | Yes | 0 bilinear, 1 trilinear, 2 to 5 for 2x to 16x anisotropic |
| `ResampleSharpness` | Yes | 0.0 to 2.0, step 0.1. Lower is sharper. Blizzard reverses the slider |
| `RAIDsettingsEnabled` | Yes | Read only by diagnostics |
| `groundEffectDensity`, `groundEffectDist`, `groundEffectFade` | No | Wiki ranges, unverified |
| `lodObjectFadeScale`, `lodObjectCullSize`, `terrainLodDist` | No | Wiki ranges, unverified |
| `horizonStart` | No | Must stay below `horizonClip`. Manual only |
| `ResampleAlwaysSharpen` | No | 0 or 1. Wiki |
| `reflectionMode`, `shadowNumCascades`, `weatherDensity` | No | Wiki ranges, unverified |
| `SSAOType` | No | Excluded. Values undocumented |

## Known limitations

- Blizzard's quality sliders rewrite raw CVars. If the user moves one after a GSM change, GSM's value is gone, and GSM does not put it back.
- Raid graphics CVars are not managed.
- Crash recovery is best effort (ADR 0002).
- Ground and terrain changes may need camera movement or a zone change to show.

## Needs in-game testing

Everything in the In-game column above, plus the checklist in [TESTING.md](TESTING.md). Open issues track SavedVariables persistence and `SetTempCVar`.
