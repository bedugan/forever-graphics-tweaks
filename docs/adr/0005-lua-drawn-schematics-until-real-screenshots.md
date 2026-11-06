# 5. Lua-drawn schematics until real screenshots exist

Date: 2026-11-06. Status: accepted.

## Context

The comparison panel should show real Forever screenshots at Low, Medium, and High. Nobody can capture them outside the client, and the brief forbids passing off fabricated images as real.

## Decision

- `Media/Manifest.lua` maps a setting and level to a packaged TGA. It ships empty in 0.1.0.
- When an image is missing, `UI/Comparison.lua` draws a schematic with textures and lines: grass density, a fade line for distance, detail blocks, and so on. Every schematic carries the caption "Schematic illustration, not an in-game screenshot".
- `docs/GRAPHICS_ASSETS.md` describes how to capture and convert real screenshots and add them to the manifest.

## Consequences

- No binary assets ship in 0.1.0, so the ZIP stays small.
- Schematics only teach the direction of a change. Real images come later through a ready-for-human issue.
