# Forever Graphics Tweaks

A World of Warcraft: Forever addon for trying advanced graphics settings without the risk. Pick a preset or adjust a setting, click Test settings, and look at the game. You have 15 seconds to keep the change. If you do nothing, it goes back.

> **Pre-release (0.1.0).** The code is complete and passes its automated tests, but nothing has been checked inside the Forever client yet. Every setting is marked unverified. Version 1.0 waits for the in-game checklist in [docs/TESTING.md](docs/TESTING.md).

Target: Forever (Camelot) 1.60.1, interface 16001.

## What it does

- Four presets: Default (the game's own defaults), Balanced, Ultra, and Custom (your edits).
- 16 settings in five groups, each with a plain description, the current and pending value, an estimated performance cost, and when the change shows up. Details in [docs/SETTINGS.md](docs/SETTINGS.md).
- A Low, Medium, High comparison panel for every setting. 0.1.0 shows labeled schematic drawings. Real screenshots can be added later ([docs/GRAPHICS_ASSETS.md](docs/GRAPHICS_ASSETS.md)).
- A safe test. FGT records the current values, applies the new ones, reads them back, closes its window, and shows a small Keep or Revert box with a 15 second countdown. Timeout reverts. If any value fails to apply, FGT undoes the rest and tells you.
- Restore original puts back the settings you had before FGT first changed anything. It asks first.
- Named profiles, such as "Mac Balanced" or "SteamOS Ultra". Loading one only fills pending values.
- Classic experience check. If you play the Classic experience, FGT warns once per session that these settings change the original look. It never changes your experience preset.
- `/fgt diag` prints a read-only compatibility report.

## What it never does

- Change any setting when the game starts or the addon loads.
- Change your Classic or Enhanced experience preset, character models, resolution, graphics API, or display.
- Apply a profile on its own.
- Reload your UI.
- Change things back after you or the game's own options change them.
- Work in combat. The window closes when combat starts.

## Install

1. Download `ForeverGraphicsTweaks-0.1.0.zip` from the [releases page](https://github.com/bedugan/forever-graphics-tweaks/releases).
2. Quit the game, or be at the login screen.
3. Unzip it into the Forever client's `Interface/AddOns` folder. You should end up with `Interface/AddOns/ForeverGraphicsTweaks/ForeverGraphicsTweaks.toc`. If you see `ForeverGraphicsTweaks/ForeverGraphicsTweaks/`, move the inner folder up one level.
4. Start the game. At character select, open AddOns and check that Forever Graphics Tweaks is enabled.

Where the folder is:

| System | Default AddOns folder |
| --- | --- |
| Windows | `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns` |
| macOS | `/Applications/World of Warcraft/_forever_/Interface/AddOns` |
| SteamOS or Linux (Proton) | Inside the Wine prefix of the Steam shortcut you use for Battle.net, for example `~/.local/share/Steam/steamapps/compatdata/<id>/pfx/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns` |

If you installed the game somewhere else, open Battle.net, pick Forever, and use Options, Show in Explorer (or Finder) to find it. Create the `Interface/AddOns` folders if they do not exist.

On SteamOS, the `<id>` is the number Steam gave your non-Steam Battle.net shortcut. In Desktop Mode, the newest folder under `compatdata` that contains `pfx/drive_c/Program Files (x86)/World of Warcraft` is usually the right one. The game does not care which system copied the files.

## Use

- Open it from Esc, Options, AddOns, Forever Graphics Tweaks, then Open. Or type `/fgt`.
- Click a preset or select a setting on the left and move its slider. Pending values show in green. Nothing changes yet.
- Click Test settings. The FGT window closes so you can see the game. Look around, and turn the camera for grass and terrain changes.
- Click Keep settings (or press Enter, or A on a gamepad) to keep them. Click Revert (or press Esc, or B) to go back. Your pending values stay so you can adjust and test again.
- Profiles, at the bottom, saves and loads named sets.
- Restore original puts back your pre-FGT settings after you confirm.

Keyboard in the window: Up and Down select a setting, Left and Right adjust it, Enter tests. A gamepad D-pad does the same.

Commands:

| Command | Does |
| --- | --- |
| `/fgt` | Open or close the window |
| `/fgt diag` | Print a read-only report: build, experience, each setting's status and values, saved data |
| `/fgt revert` | End a running test and put the old values back |

## If something goes wrong

- If a test is running when you log out or reload, FGT puts the old values back first.
- If the game crashes during a test, the client may keep the test values. Open FGT and use Restore original, or set the values back in the game's own Graphics options.
- Report problems with the output of `/fgt diag` and any BugSack error at [GitHub issues](https://github.com/bedugan/forever-graphics-tweaks/issues).

## Development

- `ForeverGraphicsTweaks/` is the addon. `Core/` has no UI and reaches the game only through `ns.api`, so tests can replace it. `UI/` builds the frames. Every setting and preset value lives in `Core/Definitions.lua`.
- `scripts/test.sh` runs the Lua 5.1 tests in a container (Docker or Colima). See [docs/TESTING.md](docs/TESTING.md).
- `scripts/build.sh` builds `dist/ForeverGraphicsTweaks-<version>.zip`.
- Design decisions are in [docs/adr/](docs/adr/), terms in [GLOSSARY.md](GLOSSARY.md), API evidence in [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md), and changes in [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
