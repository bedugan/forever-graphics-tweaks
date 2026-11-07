# 2. Preview as a transaction

Date: 2026-11-06. Status: accepted.

## Context

A preview writes several CVars, waits 15 seconds, then keeps or reverts. Writes can fail or clamp. Children of quality-level CVars get rewritten when their parent changes. The user can reload, log out, or crash during the countdown.

## Decision

`Core/Preview.lua` runs a state machine: `idle`, `previewing`, then back to `idle` through Keep, Revert, or Timeout.

Starting a preview:

1. Refuse in combat or when another preview is active.
2. Validate every pending value against Definitions and current CVar status. Any invalid value aborts before writing.
3. Capture the baseline if this is GSM's first write (ADR 0004).
4. Snapshot live values for every available managed setting.
5. Apply tier 1 then tier 2. Read back after each write.
6. If any write errors or is rejected, write the snapshot back and report which setting failed. Clamped values are accepted and reported in chat.
7. Read every managed value again (the "applied" map), then start the countdown. The deadline is `clock() + 15` using an injected clock (`GetTime` in game). An unparented driver frame checks it from `OnUpdate`, so hiding the UI does not stall it. Frame count is never used.

Revert first decides which CVars are still GSM's: any CVar whose live value no longer matches the applied map was changed by something else and is left alone. It then writes the snapshot back in tier order, re-reading each value just before writing, because reverting a parent rewrites its children. Timeout calls Revert. Nothing commits without a Keep click.

`PLAYER_LOGOUT` (which also fires on reload) reverts an active preview, so the client saves the pre-test values.

## Rejected: a crash-recovery journal

The first draft wrote the snapshot to SavedVariables before applying, to detect an interrupted preview on the next load. The client writes SavedVariables only on a clean logout or reload, and `PLAYER_LOGOUT` already reverts and would clear the journal. After a crash the journal never reaches disk. It would add code and a recovery prompt for a case it cannot catch.

## Consequences

- No silent commits. Every exit path except Keep restores the snapshot.
- After a hard crash during a test, the outcome depends on when the client last wrote `Config.wtf`. If it writes only on exit, the pre-test values survive. This is unverified and listed in the smoke test. Docs must not promise crash recovery.
- Skipping externally changed CVars means Revert can be partial. Chat reports which ones GSM left alone.
