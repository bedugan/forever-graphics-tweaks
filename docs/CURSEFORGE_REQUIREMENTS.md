# CurseForge submission requirements

Researched on 2026-11-07 against CurseForge's official support pages and public project metadata. No project was created or uploaded during this research. The signed-in author dashboard was not inspected.

## Forever is supported

CurseForge currently lists **Forever** as a World of Warcraft flavor and **1.60.1** as a game version. Its [CamelotUI files page](https://www.curseforge.com/wow/addons/camelotui/files/all?gameVersionTypeId=88568&page=1&pageSize=20&showAlphaFiles=hide) has released files tagged with both. These are CurseForge's own displayed classifications, not just the addon's description. The public flavor filter uses `gameVersionTypeId=88568`. This is a flavor type ID, not a game-version ID to copy into upload metadata.

For GSM, select World of Warcraft, class Addons, flavor Forever, version 1.60.1. Keep interface `16001` in the TOC. The TOC value comes from this project's target-client evidence in [COMPATIBILITY.md](COMPATIBILITY.md); CurseForge's public listing establishes its hosting support, not GSM's runtime compatibility. Confirm the actual version choices in the signed-in upload form before submission. Do not tag Retail or other Classic clients without testing them.

## Page and artwork

- Use a distinct English name, a one-sentence summary, and an English description that explains the actual functionality. Choose relevant categories and a license. GSM already has an MIT license. The description should disclose the pre-release status and remaining in-game checks. See [creating a project](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project).
- Prepare an original **400 by 400 PNG** avatar. The [submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips) says at least 400 square; the newer [moderation policy](https://support.curseforge.com/support/solutions/articles/9000197279-project-and-modpack-moderation-policies), modified 2026-10-22, says 400 square. Exactly 400 satisfies both. Avoid borrowed game logos, solid-color placeholders, and WebP.
- The moderation policy prohibits external file download links in the description. Do not paste the README's GitHub release download link into the listing. It also calls for accurate samples for visual mods and disclosure for misleading AI-modified showcase images. A real GSM window screenshot is the appropriate sample.
- Set the source and issue-tracker fields to the GitHub repository and its Issues page. CurseForge supports those external project links in its [submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips). Leave Experimental off for normal discovery.

## ZIP and submission

1. Create or sign into the author's account and open the [project creation page](https://authors.curseforge.com/#/projects/create/choose-game).
2. Complete the page fields and license, then upload a real ZIP. A new project needs at least one file before moderation starts. Supported game versions, release type, and changelog belong on the file. See the [creation guide](https://support.curseforge.com/support/solutions/articles/9000197241-creating-and-submitting-a-project).
3. Keep one top-level `GraphicsSettingsManager/` folder containing `GraphicsSettingsManager.toc`. CurseForge specifically requires matching folder and TOC names for WoW app detection in [known issues](https://support.curseforge.com/support/solutions/articles/9000196615-known-issues). GSM's `scripts/build.sh` follows that layout and excludes the developer capture companion.
4. Exclude `.DS_Store`, `__MACOSX`, and AppleDouble files such as `._name`. CurseForge documents Mac archive metadata rejections in [file and project types](https://support.curseforge.com/support/solutions/articles/9000197242-file-project-types-and-additional-fields). Inspect the resulting ZIP rather than assuming a compressor removed them.
5. Both the project page and file need approval before public downloads are available. File review follows page approval. See [project statuses](https://support.curseforge.com/support/solutions/articles/9000197905-project-statuses-101). A successful upload is not publication approval.

## Alpha, beta, and app visibility

The official documentation conflicts:

- [File and project types](https://support.curseforge.com/support/solutions/articles/9000197242-file-project-types-and-additional-fields), modified 2026-07-09, explicitly says a new project with an approved Release **or Beta** can sync to the app. Beta requires the user's beta preference. Alpha-only new projects remain website-only. Experimental projects do not appear in website search or sync to the app.
- The older creation guide says at least one Release is necessary. [Known issues](https://support.curseforge.com/support/solutions/articles/9000196615-known-issues), modified 2026-09-24, repeats that Release requirement.

Choose the file type to reflect actual readiness. An Alpha fits a build still awaiting basic in-game verification. Beta is reasonable once the basic load, Keep, Revert, timeout, and persistence checks have results. These are release recommendations, not additional CurseForge rules. Do not mark an unverified build Release just to obtain app discovery. Do not promise beta-only first-project app visibility without checking the actual result or getting clarification from CurseForge support.

## Later automation

The [CurseForge upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api) supports uploading files to an existing project using a project ID and API token, including changelog, game version metadata, release type, and manual release scheduling. Its game versions endpoint provides the upload IDs. First establish the project and verify the manual upload path. Automation does not remove moderation or establish client compatibility.

## Remaining uncertainties

- Brian confirmed there is no existing CurseForge project for GSM. Project creation, its numeric ID, and the current signed-in session still need verification.
- Exact dashboard category options, name availability, and upload version IDs remain to be confirmed in the author dashboard. A web search found no indexed exact-name result for Graphics Settings Manager, which does not prove the name is available.
- Approval time and beta-only initial app discovery cannot be guaranteed.
- Local tests and a successful package build do not replace the game's safety and persistence checks in [TESTING.md](TESTING.md).
