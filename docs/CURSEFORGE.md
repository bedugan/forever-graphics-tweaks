# Publish Graphics Settings Manager

Submitted 2026-11-07. CurseForge project creation and the first Beta upload are complete. The author dashboard reports that the new project still requires moderator approval; the uploaded file was last observed as Processing. It is configured to publish automatically once approved. Public availability has not yet been established.

## Submission record

| Item | Value |
| --- | --- |
| Project ID | `1790216` |
| Author dashboard | <https://authors.curseforge.com/#/projects/1790216/files> |
| Intended public URL | <https://www.curseforge.com/wow/addons/graphics-settings-manager>, pending approval |
| File ID | `9499685` |
| File display name | Graphics Settings Manager 0.1.0 beta |
| Game version | Forever 1.60.1 |
| Release type | Beta |
| Source commit | `af1186ab73be975d907e9ea3fd4cf2e20913ef88`, merge of PR #12 |
| Uploaded ZIP SHA-256 | `28716c167d0b2c1d2acf1b0c22ddcfa3b33c97787dc997aef22163d7ede6aed7` |
| Uploaded ZIP size | 5,762,227 bytes |
| Contents | 53 files, including 33 textures for 11 settings; five schematic comparisons |
| License | MIT License, verified saved in the dashboard |
| Distribution | Allow distribution to third parties, explicitly chosen by Brian and verified saved |
| Source link | GitHub repository URL, verified saved; automatic packaging is off |

The local upload receipt is `dist/curseforge/build-receipt.json`. Do not upload another copy of 0.1.0 to resolve a processing or moderation wait. Check the existing file and any moderator feedback first.

## Review snapshot before the release merge

- PR [#10](https://github.com/bedugan/graphics-settings-manager/pull/10) implemented the 0.1.0 pre-release and was merged. It received three rounds of adversarial review. Quality-level rewrites affecting apply and restore were fixed with regression tests.
- The project was renamed from Forever Graphics Tweaks to Graphics Settings Manager so the name can remain useful if support expands. Current compatibility remains Forever only.
- PR [#11](https://github.com/bedugan/graphics-settings-manager/pull/11) added the developer capture companion and automatic screenshot cropping. It received two rounds of adversarial review and was merged.
- Commit `23184c47a2c62d7655a484ec9657235088459490` on local branch `fix/capture-feedback` addresses the first Mac capture session. It is not on origin/main as checked on 2026-11-07.
- Brian reported that hiding the UI, the caption band, and Esc cancellation worked during capture, with no BugSack errors. This establishes some companion behavior, not completion of the main addon's safety checklist.
- The follow-up capture sessions and screenshot review produced 11 committed screenshot sets. Ten were taken at 100% render scale; small object culling uses an earlier 50% set. Five settings retain schematics. The release candidate must include those 33 committed TGA files.
- Brian confirmed on 2026-11-07 that Keep, Revert, the 15-second timeout, Restore original, and profile persistence after restarting the Forever client all passed. These are owner-reported results. The exact test build, OS, and package revision were not supplied in that confirmation.
- Current automated verification: 90 Lua tests and 12 synthetic image-import tests pass. All Lua files parse, and the generated settings reference matches the definitions.
- GitHub milestone issues #1 through #5 remain open despite the merged implementation. In-game smoke testing (#6), screenshot work (#7), and persistence (#8) also remain open. Issue state alone is not an implementation ledger.

## Release type

0.1.0 was submitted as a **Beta** following Brian's confirmation that the core safety and persistence checks passed. CurseForge supports Forever 1.60.1. An alpha-only first project is website-only according to its documentation. Do not label it Release to obtain app discovery. Beta-only first-project discovery is unclear because the official documents conflict.

For a stable Release and normal app launch, finish the remaining checklist and confirm a clean install of the actual packaged ZIP. Keep the remaining checks separate from the safety and persistence results Brian has now reported. The full checklist remains [TESTING.md](TESTING.md).

The original prototype's 1.0 gate is unchanged. A capture session is not a completed smoke test.

## Submission fields

| Field | Prepared value |
| --- | --- |
| Game and class | World of Warcraft, Addons |
| Name | Graphics Settings Manager |
| Project slug | `graphics-settings-manager` |
| Summary | Try advanced Forever graphics settings with presets, profiles, and a 15-second Keep or Revert timer. |
| Description | [CURSEFORGE_DESCRIPTION.md](CURSEFORGE_DESCRIPTION.md), starting with the title or first paragraph as the editor requires |
| Category | Miscellaneous |
| License | MIT License |
| Source | `https://github.com/bedugan/graphics-settings-manager` |
| Issues | `https://github.com/bedugan/graphics-settings-manager/issues` |
| File display name | Graphics Settings Manager 0.1.0 beta |
| Release type | Beta, based on owner-reported safety and persistence results |
| Flavor and game version | Forever, 1.60.1 |
| Dependencies | None |
| Avatar | Original 400 by 400 PNG at `assets/curseforge/landscape-controls.png`; two alternatives are alongside it |

Do not paste a GitHub release download link into the description. Use CurseForge's Source and Issues fields for repository links. Add an actual in-game screenshot of the GSM window if requested for moderation. Imported effect crops are not a screenshot of the addon window.

## Build the candidate

Run this only after the reviewed release PR has merged. Before that merge, `origin/main` still contains the previous implementation. Fetching and naming the source ref explicitly avoids depending on the checked-out branch.

```sh
git fetch origin
scripts/build.sh --ref origin/main
unzip -t dist/GraphicsSettingsManager-0.1.0.zip
mkdir -p dist/curseforge
cp dist/GraphicsSettingsManager-0.1.0.zip dist/curseforge/GraphicsSettingsManager-0.1.0.zip
shasum -a 256 dist/curseforge/GraphicsSettingsManager-0.1.0.zip
```

`--ref` packages committed files from that revision and includes the MIT license. It includes the committed screenshot manifest and textures while leaving any local edits untouched. The ZIP has one `GraphicsSettingsManager/` root and excludes the capture companion. Running the build without `--ref` includes working-tree edits, including any future screenshot changes that have not been committed.

Upload `dist/curseforge/GraphicsSettingsManager-0.1.0.zip` only after refreshing that copy with the commands above. Verify that both ZIPs have the same SHA-256, the archive contains all 33 screenshot textures, and its files match the source commit. Refresh `dist/curseforge/build-receipt.json` with that source commit, checksum, file size, screenshot count, and test results. An older receipt or copied ZIP does not describe a new build. The publication directory also holds the artwork options, listing description, and changelog. It is ignored by git.

## File changelog

Initial beta for World of Warcraft: Forever 1.60.1. Includes 16 graphics controls, Default/Balanced/Ultra/Custom presets, a 15-second Keep or Revert test, named profiles, Restore original, 11 in-game screenshot comparisons, five schematic comparisons, and `/gsm diag`. No graphics changes are applied at login. The developer capture companion is not included. Balanced adjusts five settings and leaves the others unchanged. Keep, Revert, timeout, Restore original, and profile persistence after a client restart passed owner testing. The full compatibility checklist remains in progress.

## Submit and verify

1. Open the [existing project](https://authors.curseforge.com/#/projects/1790216/files). Do not create a second project.
2. Review the prepared page, choose an avatar, and fill the project fields. Confirm Forever and 1.60.1 are offered on the upload form. Do not choose another client to get past a missing option.
3. Upload the candidate ZIP with its changelog and the agreed release type. A new project needs a file before moderation proceeds.
4. Check both project approval and file approval. Upload completion alone does not mean publication.
5. Once approved, verify the public project URL, Forever/version labels, downloadable file, and clean install. Check app discovery separately for a release type intended for the app.
6. After approval, verify the public page, download, and app visibility, then update this record. Configure the GitHub issue tracker if the pending-project Issues control becomes available. Add `X-Curse-Project-ID` and upload automation later if useful.

## Sources

See [CURSEFORGE_REQUIREMENTS.md](CURSEFORGE_REQUIREMENTS.md) for the current official policies, source links, and discovery uncertainty. Project history was checked against git, GitHub PRs and issues, and the prior project conversation.
