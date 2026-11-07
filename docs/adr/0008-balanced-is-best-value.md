# 8. Balanced is the best-value preset

Date: 2026-11-07. Status: accepted.

## Context

The first Balanced values were estimates. They raised most settings a step or two above the defaults. The 2026-11-07 capture session on a Mac at 100% render scale showed that many of those steps change almost nothing on screen. It also showed that the game's defaults for texture filtering (16x) and water reflections (3) are already the highest values, so the old Balanced 8x filtering was a step down.

The numbers below are the share of pixels that changed between captured levels. The control column compares Low with a second Low shot taken a few seconds later. It measures what moves on its own, such as water, swaying plants and fog. A change near the control figure is not a visible difference.

| Setting | Default | Low, Medium, High | Low to Medium | Medium to High | Control |
| --- | --- | --- | --- | --- | --- |
| View distance level | 6 | 0, 5, 9 | 7.8% | 1.9% | 0.6% |
| Environment detail level | 6 | 0, 5, 9 | 2.9% | 1.1% | 2.5% |
| Ground clutter level | 6 | 0, 5, 9 | 2.9% | 3.8% | 0.7% |
| Grass density | 16 | 16, 136, 256 | 5.2% | 4.3% | 1.3% |
| Grass draw distance | 70 | 40, 270, 500 | 4.8% | 4.6% | 3.1% |
| Grass fade start | 70 | 40, 270, 500 | 4.3% | 4.3% | 4.9% |
| Object fade distance | 100 | 50, 180, 300 | 9.3% | 2.6% | 2.4% |
| Small object culling | 15 | 30, 17, 4 | 1.7% | 2.5% | 2.6% |
| Terrain detail distance | 400 | 200, 850, 1500 | 1.0% | 2.3% | 0.6% |
| Horizon detail start | 800 | 400, 3200, 6000 | 9.1% | 0.8% | 0.8% |
| Shadow cascades | 1 | 1, 3, 4 | 11.2% | 4.1% | 5.2% |
| Water reflections | 3 | 0, 2, 3 | 7.3% | 11.6% | 8.9% |
| Texture filtering | 5 | 0, 3, 5 | 11.3% | 8.1% | 6.4% |

One scene per setting, all on Zephras Isle, which is foggy. Open zones may show more from distance settings.

## Decision

Balanced sets the lowest value that looked different from the game's default. Where the default already looked as good as higher values, Balanced leaves the setting alone.

- Quality levels stay unchanged. Their defaults (6) already sit above the captured Medium (5), and Medium to High changed little.
- Grass draw distance 270, the captured Medium. Fade start follows at 230, because it must not exceed draw distance.
- Grass density 64. The capture only shows that 136 is clearly fuller than 16, so 64 is an estimate, kept below Ultra's 128.
- Object fade distance 150, an estimate between the default of 100 and 180, where the gain stops.
- Shadow cascades 3. One to three is the largest change of any setting. Three to four is within the control.
- Small object culling, terrain detail distance, Always sharpen and texture filtering stay unchanged.
- Horizon detail start stays out of every preset, even though 3200 shows a lot more distant buildings than 800. It must stay below the horizon clip distance, and the view distance level can change that distance from one machine to the next.

Ultra keeps its values.

## Consequences

- Balanced changes 5 settings instead of 11, so its frame rate cost is lower and it no longer lowers texture filtering.
- A player whose quality levels are below the default keeps them under Balanced. Default restores them.
- The values come from one Mac session. A SteamOS session may move them.
