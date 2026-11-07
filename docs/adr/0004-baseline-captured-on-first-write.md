# 4. Baseline captured on first write

Date: 2026-11-06. Status: accepted.

## Context

Restore Original needs the player's configuration from before GSM changed anything. Capturing at addon load could record values GSM itself set in a previous session if the baseline was lost.

## Decision

GSM captures the baseline once, just before its first write of any CVar (the first preview). It records the live value of every available setting, not only the ones being changed. The baseline lives in SavedVariables and is never overwritten automatically. The user can reset it from the window, after a confirmation, to make the current values the new baseline.

Restore Original writes the baseline back through the same validate, apply, readback path as a preview, but without a countdown, after a confirmation dialog.

## Consequences

- If SavedVariables fail to persist on Forever, the baseline is lost and gets re-captured from whatever is live. Issue "Verify SavedVariables persistence on 70790" tracks this. Diagnostics shows a load counter so the user can tell.
- A setting added in a later GSM version gets added to the baseline the first time GSM writes it.
