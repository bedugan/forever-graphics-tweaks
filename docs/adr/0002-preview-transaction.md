# 2. Preview as a transaction with a journal

Date: 2026-11-06. Status: accepted.

## Context

A preview writes several CVars, waits 15 seconds, then keeps or reverts. Writes can fail or clamp. Children of quality-level CVars get rewritten when their parent changes. The user can reload, log out, or crash during the countdown.

## Decision

`Core/Preview.lua` runs a state machine: `idle`, `previewing`, then back to `idle` through Keep, Revert, or Timeout.

Starting a preview:

1. Refuse in combat or when another preview is active.
2. Validate every pending value against Definitions and current CVar status. Any invalid value aborts before writing.
3. Snapshot live values for every CVar that will change.
4. Write the journal (snapshot plus applied values) to SavedVariables.
5. Apply tier 1 then tier 2. Read back after each write.
6. If any write errors or is rejected, restore everything already written in reverse order, clear the journal, and report which setting failed. Clamped values are accepted and shown to the user.
7. Start the countdown. The deadline is `clock() + 15` using an injected clock (`GetTime` in game), checked from `OnUpdate`. Frame count is never used.

Revert writes the snapshot back, tier 2 first and then tier 1, in reverse apply order. It skips any CVar whose live value no longer matches what FGT applied, because something else changed it. Timeout calls Revert. Nothing commits without a Keep click.

`PLAYER_LOGOUT` (which also fires on reload) reverts an active preview, so the saved config is the pre-test one. If FGT loads and finds a journal, the previous session ended mid-preview without a clean logout. FGT does not touch CVars at load. It shows a prompt offering to restore the journaled values or discard the journal.

## Consequences

- No silent commits. Every exit path except Keep restores the snapshot.
- Crash recovery is best effort. If the client dies before it writes `Config.wtf`, the previewed values may never persist anyway. If it writes `Config.wtf` but not SavedVariables, FGT has no journal. Docs must not promise more.
- Skipping externally changed CVars means Revert can be partial. The overlay reports which ones it left alone.
