# 6. Pure core with injected API, tested in a Lua 5.1 container

Date: 2026-11-06. Status: accepted.

## Context

The preview and CVar handling are the riskiest code, and the game client cannot run in CI or on the dev Mac's command line.

## Decision

- Modules under `Core/` take their WoW API (`C_CVar`, `C_GameRules`, `Enum`, clock, SavedVariables table) as an injected environment. They do not create frames.
- `UI/` modules create frames and call into Core. They are not unit tested.
- `tests/` holds a small runner and mocks. `scripts/test.sh` runs them in the `nickblah/lua:5.1` image through Colima, and runs `luac -p` on every addon file.

## Consequences

- The preview state machine, readback, rollback, timeout, preset fill, and profile logic get automated tests.
- Frame layout, protected-call behavior, and real CVar effects need the in-game checklist in `docs/TESTING.md`.
- No test framework dependency. The runner is under 100 lines.
