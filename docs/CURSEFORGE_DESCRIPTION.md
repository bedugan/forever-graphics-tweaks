# Graphics Settings Manager

Try advanced graphics settings in World of Warcraft: Forever with a 15-second Keep or Revert timer.

**Beta for Forever 1.60.1, interface 16001.** Keep, Revert, the 15-second timeout, Restore original, and profile persistence after a client restart have passed owner testing in the Forever client. Automated tests also pass. The full compatibility checklist remains in progress. Please report problems with your client build and `/gsm diag` output.

## Try a change before keeping it

Choose Default, Balanced, or Ultra, or adjust individual settings. Balanced changes five settings based on the capture sessions and leaves the others at their current values. Your edits stay pending until you click **Test settings**. GSM applies the changes and closes its window so you can look at the game. Choose **Keep settings** within 15 seconds, or let the timer put the previous values back. You can also choose **Revert** yourself.

## Understand the settings

GSM groups 16 controls into quality levels, ground vegetation, object and terrain detail, image quality, and other enhancements. Each control explains what it changes, its estimated performance cost, and when the effect should appear. Low, Medium, and High comparison panels show in-game screenshots for 11 settings and labeled schematic illustrations for the other five. The screenshots were captured in Forever 1.60.1. Most were taken at 100% render scale; the small object culling set uses an earlier 50% render scale capture where the difference was clearer.

## Save profiles and restore your starting point

Save named profiles for later. Loading a profile fills your pending values; it does not apply them. **Restore original** asks before restoring the settings recorded before GSM first changed anything.

## Open the addon

Type `/gsm`, or open Options, AddOns, Graphics Settings Manager. The window supports mouse, keyboard, and gamepad input. Type `/gsm diag` for a compatibility report and `/gsm revert` to end a running test.

## Scope and known limits

- Targets Forever 1.60.1. Compatibility with Retail and other Classic clients has not been established.
- Does not apply graphics changes at login, change your Classic or Enhanced experience preset, or manage resolution and graphics API selection.
- Does not manage separate raid graphics settings.
- Ground and terrain changes may need camera movement or more time to become visible.
- A hard client crash during a test can leave the test values applied. Use Restore original or the game's Graphics options afterward.
- Preset performance costs are estimates. GSM does not benchmark your hardware.

No additional addon is required. The screenshot capture companion is a separate developer tool and is not included.
