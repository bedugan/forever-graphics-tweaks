# Brief review

A review of the original project brief, written before implementation. It records where the brief was wrong, ambiguous, or bigger than it needs to be, and what this repo does about each point.

Sources: Blizzard's UI source on the `forever` branch at build 1.60.1.70790 (Gethe/wow-ui-source, commit `eac30af`), Thunderz96/forever-addon-kit (MIT), drengalis/foreverGraphics (no license, read for ideas only), and warcraft.wiki.gg.

## Corrections

1. **The enum value is Enhanced, not Modern.** `GameRulesDocumentation.lua` defines `Enum.ForeverExperiencePreset` as `Classic = 0`, `Enhanced = 1`. GSM uses the enum names, not the numbers, and treats anything else as Unknown.
2. **`ssaoType` is not a clear target.** The live CVar is `SSAOType`, its values are not documented in the UI source, and Blizzard's own Graphics panel already exposes SSAO quality. GSM leaves SSAO out.
3. **Most raw CVars in the brief are children of Blizzard's quality sliders.** `graphicsViewDistance`, `graphicsEnvironmentDetail`, and `graphicsGroundClutter` (0 to 9) set values such as `groundEffectDensity`, `terrainLodDist`, and `lodObjectCullSize`. Moving a Blizzard slider overwrites GSM's raw values. GSM applies parents first, then children, and does not fight the game afterward.
4. **Raid graphics mirrors exist.** When `RAIDsettingsEnabled` is on, a second set of `raidGraphics*` CVars applies in raids and battlegrounds. GSM 0.1.0 does not manage them. Diagnostics reports the flag so the user knows.
5. **None of the target CVars needs a restart.** Blizzard's panel marks none of the related settings with the GxRestart commit flag. A separate restart workflow is not needed. A `previewable` flag in Definitions is enough if a future setting needs it.

## Risks the brief understates

- **In-game validation needs the user.** No one can run the Forever client from this repo. Every setting ships marked unverified, and 0.1.0 is a pre-release. 1.0 waits for the smoke test in `docs/TESTING.md`.
- **Hiding `SettingsPanel` risks taint.** See ADR 0001. GSM uses its own window so the preview never touches Blizzard frames.
- **SavedVariables on Forever.** Early beta builds had reports of SavedVariables not loading. Unverified on 70790. The baseline and profiles depend on it, so diagnostics shows a load counter.
- **Crash recovery is limited.** The client writes `Config.wtf` and SavedVariables on a clean exit. A hard crash may skip both. ADR 0002 explains why GSM does not try to journal a test.
- **Some changes are not visible within 15 seconds.** Ground clutter and terrain LOD load as the world streams. The overlay tells the user to move the camera, and the setting text says when an effect is delayed.

## Scope cuts

- No before/after drag slider. Low, Medium, High tabs teach the same thing with less code.
- No real screenshots in 0.1.0. Schematics are labeled as such (ADR 0005), and a ready-for-human issue tracks real captures.
- No raid graphics, no SSAO, no hardware detection, no auto-apply at login.

## Decisions taken with the owner

| Question | Decision |
| --- | --- |
| Remote repo | Public GitHub repo `bedugan/forever-graphics-tweaks` |
| UI shell | Own window, Settings canvas as a launcher (ADR 0001) |
| In-game gate | Build M1 to M5 as 0.1.0 pre-release, all settings unverified |
| Lua tests | Lua 5.1 container through Colima (ADR 0006) |
