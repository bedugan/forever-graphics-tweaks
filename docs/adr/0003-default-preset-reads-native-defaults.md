# 3. Default preset reads native defaults at runtime

Date: 2026-11-06. Status: accepted.

## Context

The Default preset should use the client's native defaults. Hard-coding Retail numbers risks being wrong on Forever, and Forever may change them between builds.

## Decision

The Default preset has no numbers in Definitions. When the user picks it, GSM fills pending values from `C_CVar.GetCVarDefault` for each available setting. Settings whose default cannot be read stay unchanged.

## Consequences

- Default stays correct across builds without code changes.
- The UI cannot show Default values for a CVar the client does not report.
- Default is clearly separate from Restore Original, which uses the captured baseline.
