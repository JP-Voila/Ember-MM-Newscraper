# CLAUDE.md

Guidance for AI coding agents (Claude Code and others) working in this repository.
Read this before touching any code. See also [SECURITY.md](SECURITY.md).

**Start every session by reading [docs/WORKLOG.md](docs/WORKLOG.md)**: current status,
open items, in-progress investigations (e.g. TVDB API) and session history. Before
ending a session, update it (status, open items, a dated history entry).

## What this is

**Ember Media Manager (EMM)** — a Windows desktop media manager for movies, movie sets
and TV shows. It scans local video sources, scrapes metadata/artwork/trailers/themes from
online services (TMDB, IMDB, TVDB, OMDb, Trakt.tv, Fanart.tv, YouTube, …), stores
everything in a local SQLite database, and writes Kodi-compatible NFO files and images
next to the media.

- Fork of `DanCooper/Ember-MM-Newscraper`; maintained here by the repo owner for personal
  use. Upstream development stopped around late 2022 (last upstream commit: 2022-12-03).
- **Goal of current work:** fix bugs ("niggles") in an app that is still used daily.
  Not a rewrite, not a modernisation project. Prefer small, targeted, low-risk fixes.
- Licence: GPL v3 (`EmberMediaManager/License.txt`). Every source file carries the
  GPL header block — keep it on new files.

## Tech stack

| Area | Detail |
|---|---|
| Language | VB.NET (main app, API, all addons); C# for `KodiAPI` and `Trakttv` |
| Framework | .NET Framework **4.8** (`EmberAPI`, `EmberMediaManager`); some libs still 4.5 |
| UI | Windows Forms (designer files `*.Designer.vb` + `*.resx`) |
| Database | SQLite via `System.Data.SQLite` 1.0.115.5 |
| Logging | NLog 4.7 (`EmberAPI/NLog.config`) |
| JSON | Newtonsoft.Json 13 |
| Packages | Legacy `packages.config` + `.nuget/NuGet.exe` restore (not PackageReference) |
| Installer | NSIS (`BuildSetup/1.4_InstallerScript.nsi`, `0_BuildSetup_x64/x86.bat`) |
| Build | Visual Studio / MSBuild on Windows. Solution: `Ember Media Manager.sln` |

VB projects compile with `Option Strict On`, `Option Explicit On`, `Option Infer On`.

## Building and testing — read this

**This project only builds and runs on Windows** (WinForms + .NET Framework 4.8 + native
SQLite interop DLLs in `EmberAPI/x86` and `EmberAPI/x64`).

- In a Linux/cloud agent session there is **no compiler available**. You cannot build,
  run or test. Be explicit about that in your summary: say what you changed, why you
  believe it is correct, and what the owner should check manually on Windows.
- Because nothing compiles here, be extra careful with: `Option Strict` implicit
  conversions, `Handles` clauses, `Implements` signatures, designer-generated control
  names, and `ByRef`/`ByVal` changes. Grep for every caller before changing a signature.
- On Windows: open `Ember Media Manager.sln` in Visual Studio, restore NuGet packages,
  build `Debug|x64` (or x86). Output goes to `<repo>\EmberMM - <Config> - <Platform>\`,
  **inside** the repo root and git-ignored (`EmberMM*/`). Addons build into its
  `Modules\` subfolder.
- **Command-line build (verified 2026-10-31, VS Build Tools 2026 + .NET 4.8 targeting
  pack):**
  ```
  MSBuild.exe "Ember Media Manager.sln" -t:restore -p:RestorePackagesConfig=true -p:Configuration=Debug -p:Platform=x64
  MSBuild.exe "Ember Media Manager.sln" -p:Configuration=Debug -p:Platform=x64 -m -v:minimal
  ```
  MSBuild lives at
  `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\MSBuild\Current\Bin\`.
  Restore puts packages in `<repo>\packages\` (git-ignored).
- **Vendored dependency:** `External/TheTVDBApi/` is a copy of
  [DanCooper/TheTVDBApi](https://github.com/DanCooper/TheTVDBApi) (C#, GPL v3) used by
  `scraper.Data.TVDB` and `scraper.Image.TVDB`. It is now maintained here — edit it in
  place and log changes in `External/TheTVDBApi/UPSTREAM.md`. It targets TheTVDB's
  legacy XML API, which TheTVDB has been retiring in favour of API v4.
- `EmberAPI_Test` is an MSTest project that is **not included in the solution** and is
  largely stale (references NLog 3.1 / `UnitTestFramework` 10.x). Don't rely on it; if you
  add tests, say so and note they have not been run.
- **Testing rules live in [docs/TEST_STANDARD.md](docs/TEST_STANDARD.md):** the four
  layers (build / unit / test library / manual), fixtures, bites, and the bug lane
  (failing test committed before the fix).

## Repository layout

```
Ember Media Manager.sln     Main solution (all projects)
EmberMediaManager/          The WinForms executable: frmMain + all dlg* dialogs
  frmMain.vb                ~19k lines — main window, list views, task orchestration
  dlgEdit_*.vb              Edit dialogs per content type (Movie/Movieset/TVShow/Season/Episode)
  dlgSettings.vb            Settings dialog host; MasterSettingsPanels/ holds panels
EmberAPI/                   Core library shared by the app and every addon
  clsAPIDatabase.vb         ~6.3k lines — all SQLite access, schema creation & upgrades
  clsAPIModules.vb          Addon discovery/loading (reflection over Modules\*.dll)
  clsAPIInterfaces.vb       Interfaces addons implement (GenericModule, ScraperModule_*)
  clsAPIMediaContainers.vb  Data model (MediaContainers.Movie, .EpisodeDetails, …)
  clsAPINFO.vb              NFO read/write (Kodi format)
  clsAPIImages.vb           ALL image load/save/download logic lives here
  clsAPIScanner.vb          Folder scanning / file detection
  clsAPISettings.vb         Settings model; persisted to Settings.xml
  clsAPIHTTP.vb             HTTP helper used by scrapers
  clsAPILocalization.vb     Translation lookup (Master.eLang.GetString)
  clsAPITaskManager.vb      Background task runner
  DB/                       MyVideosDBSQL.txt (schema) + MyVideosDBSQL_vN_Patch.xml (upgrades)
  Defaults/                 Default XML config files shipped with the app
  Translations/             en-US.xml (+ db-DB.xml); other languages come from Transifex
Addons/                     Plug-in modules, one project each
  scraper.<Kind>.<Source>   Data / Image / Trailer / Theme scrapers
  generic.EmberCore.*       Built-in tools (BulkRename, TagManager, MovieExport, …)
  generic.Interface.*       Integrations (Kodi JSON-RPC, Trakt.tv)
External/TheTVDBApi/        Vendored C# TVDB client (see UPSTREAM.md in that folder)
KodiAPI/                    C# Kodi JSON-RPC client library
Trakttv/                    C# Trakt.tv API client library
BuildSetup/                 Installer scripts and Transifex download tooling
docs/WORKLOG.md             Agent worklog: status, open items, investigations, history
docs/BUGS.md                Owner-reported bugs (BUG-NNN): symptom, findings, status
docs/INVENTORY.md           What every project/file does, key flows, state, change seams
docs/TEST_STANDARD.md       What a test must be; test layers; bug lane
docs/SETTINGS.md            Dev-build defaults: modules/scrapers on/off, key behaviour flags
docs/tmp/                   Git-ignored scratch: owner logs, test output
tools/New-TestLibrary.ps1   Creates the git-ignored L3 test library in testlib/
tools/Export-DefaultSettings.ps1  Dumps the build's default Settings.xml (+ flat listing)
ImageSources/, SourceImages/  Design source art (not compiled)
Changelog.txt               Historic changelog (top entry is 1.4.7.2 / 2015 — stale)
```

Folder names under `Addons/` do not always match project names
(e.g. `scraper.TMDB.Data/scraper.Data.TMDB.vbproj`). Use the `.sln` as the source of truth.
Three addons also carry their own standalone `.sln` — ignore those; use the main solution.

## Architecture essentials

- **Addons are loaded by reflection** at startup: `clsAPIModules.vb` enumerates
  `Modules\*\*.dll`, calls `Assembly.LoadFile`, and instantiates every type that implements
  one of the interfaces in `clsAPIInterfaces.vb`. Changing an interface breaks every
  addon that implements it — update them all in the same change.
- **Scrapers are deliberately split** into Data / Image / Trailer / Theme groups (see
  README). Data scrapers run sequentially and only fill selected, empty, unlocked fields.
  Image scrapers run in parallel and return lists; the image-select dialog lives in the
  main app, not in scrapers. Each data scraper owning its own search dialog is a known,
  accepted duplication — don't "fix" it.
- **IMDB id is the unique identifier for movies.** TVDB id for TV shows.
- **Database:** `Database.Connect_MyVideos` in `clsAPIDatabase.vb` holds
  `MyVideosDBVersion` (currently **48**). The DB file is `MyVideos48.emm` in the profile
  folder. On startup, an older `MyVideos<N>.emm` is copied and upgraded by applying
  `DB/MyVideosDBSQL_v<N>_Patch.xml` … up to the current version.
  **Any schema change requires:** bump `MyVideosDBVersion`, add a new
  `MyVideosDBSQL_v<old>_Patch.xml`, update `MyVideosDBSQL.txt` (fresh-install schema),
  and add the new files to `EmberAPI.vbproj` with "Copy to Output". Avoid schema changes
  for bug fixes unless truly necessary — they are one-way for the user's library.
- **Settings** are serialized to `Settings.xml` under `Master.SettingsPath` (per profile).
  Adding a property to the settings classes is fine; renaming/removing one silently
  drops the user's stored value. Defaults are set in `clsAPISettings.vb`.
- **NFO/image output** is what Kodi reads. Changes to `clsAPINFO.vb` or file-naming logic
  affect files on the user's disk — call these out explicitly in your summary.

## Coding conventions

Match the surrounding code. In particular:

- 4-space indentation, VB keywords PascalCase, UTF-8 **with BOM** for `.vb` files
  (existing files have a BOM — keep it). Git normalises line endings (`* text=auto`).
- Logger per class: `Shared logger As Logger = LogManager.GetCurrentClassLogger()`.
  Error logging idiom:
  `logger.Error(ex, New StackFrame().GetMethod().Name)` (optionally `& vbTab & context`).
- User-visible strings go through localization:
  `Master.eLang.GetString(<id>, "English fallback")`. Reuse an existing id when the text
  already exists in `EmberAPI/Translations/en-US.xml`; a new string needs a new, unused
  id added to `en-US.xml`.
- Don't edit `*.Designer.vb` by hand unless the change is trivial and mechanical
  (e.g. a property value); control declarations and `Handles` must stay in sync with the
  matching `.vb` file and `.resx`.
- No large reformatting, renaming or "modernising" passes mixed into bug fixes. Keep
  diffs minimal and reviewable.
- Commit message style used in history: lower-case prefix, e.g.
  `fixed: <what>`, `added: <what>`, `changed: <what>`, `code: cleanup`.

## Working principles

- **Root cause, not workaround.** Diagnose the root cause. No patches or workarounds
  unless explicitly requested.
- **Simplicity.** Use the cheapest mechanism that closes the defect; deletion is preferred.
  "Smaller" means fewer *mechanisms*, never fewer lines.
- **Checks must be able to fail.** A zero, empty or absent result counts only next to a
  positive control that proves the check can fire. Examples in this codebase:
  - "No `ERROR` in the log" proves nothing if the code path logs `[Done]` whether or not
    it worked (`TVDB_Data.Scraper_TVEpisode`).
  - A grep with no hits proves nothing if the pattern would not have matched the real
    spelling.

  Confirm the check finds a known positive first.
- **Enumerate first.** Fix a class of bug from a mechanically listed set of instances,
  never one instance at a time from where it was first seen. Ember's architecture
  repeats itself: every `Scraper_TVEpisode`, every trailer scraper, every `dlgEdit_*`.
  When one implementation is wrong, grep for all its siblings before deciding the scope
  of the fix.
- **Works and safe are separate requirements.** Both are mandatory. See SECURITY.md.
- **Comment the why, not the what.** No new `TODO` without a `BUG-NNN` reference.

## Change checklists

**Adding a property to a data class** (`MediaContainers.*`, `Database.DBElement`). A
missed step means the value is silently lost, not an error:
1. **Cloning.** `CloneDeep` uses `BinaryFormatter` (`clsAPIDatabase.vb`,
   `clsAPIMediaContainers.vb`). The property's type must be `<Serializable()>`.
2. **NFO.** Decide `<XmlElement(...)>` vs `<XmlIgnore()>`. Add a `…Specified`
   property if the element should be omitted when empty.
3. **Database.** Add the property to the load *and* save paths in `clsAPIDatabase.vb`.
   A new column is a schema change: see "Architecture essentials".
4. **Merge.** Scraper results reach the DB through `NFO.MergeDataScraperResults_*`
   (`clsAPINFO.vb`). A field not merged there never leaves the scraper.

**"Unset" values are sentinels, not zero.** Numbers use `-1` for "not set"
(`EpisodeDetails.Season`/`.Episode`). `SeasonDetails.Season` uses `-2`, because `-1`
means "* All Seasons". Season `0` (specials) is a real value. Always test the existing
`…Specified` property; never compare against `0`, `-1` or `> 0` yourself.

## Workflow for bug fixes

1. Get a precise symptom from the owner (steps, content type, which scraper, log excerpt
   from `<install dir>\Log\<yyyy-MM-dd>.csv` — NLog config in `EmberAPI/NLog.config`).
   Record it in [docs/BUGS.md](docs/BUGS.md) as the next `BUG-NNN`.
2. Logs and other owner-supplied scratch files go in `docs/tmp/`. It is git-ignored,
   because logs contain personal media paths. Logs are large: grep for the relevant
   lines (`[TVEpisodeScraper]`, `[<Scraper>_Data]`, `ERROR`) instead of reading the
   whole file.
3. Locate the code path — grep for the localized message text or the UI control name;
   `frmMain.vb` and `clsAPIDatabase.vb` are huge, so search rather than read top-down.
4. Explain the root cause before changing code. Write the findings (with `file:line`)
   into the bug's entry in BUGS.md. Then reproduce it as a failing test and commit that
   first (TEST_STANDARD §7).
5. Make the smallest fix that addresses it. Check all call sites of anything you touch,
   and all sibling implementations (see "Enumerate first"). Pick the most isolated seam
   that closes the defect ([docs/INVENTORY.md](docs/INVENTORY.md) §8). Make one commit
   per bug with `BUG-NNN` in the message, so each fix can be reverted on its own.
6. Summarise: root cause, the change, risk, and a manual test plan for Windows. Update
   the bug's status in BUGS.md.
7. Optionally add an entry to `Changelog.txt` if the owner wants one.

`file:line` references in BUGS.md and WORKLOG.md were correct when written and drift as
code changes. Re-check them before relying on them.

**Bugs found incidentally** (while working on something else) are logged in BUGS.md as
a new `BUG-NNN` with what was seen and where. Fix them later, as their own change, not
inside the current one. The source of the bug can be the owner, a log, or code reading.

Many "bugs" in a 2022-era scraper app are really **upstream API changes** (sites changed
HTML, APIs deprecated/versioned, endpoints moved, keys revoked). Check that first for any
scraper failure — e.g. HTML-scraping addons (IMDB, OFDB, Moviepilot, Videobuster,
Apple trailers, Dave's trailer page, TelevisionTunes) are the most likely to be broken.

## Things not to do

- Don't commit secrets, API keys, personal media paths, `Settings.xml`, databases
  (`*.emm`) or log files. See SECURITY.md about the API keys already in the source.
- Don't upgrade NuGet packages or retarget frameworks as a side effect of a bug fix.
  When the owner approves an upgrade (e.g. a parser or download library), make it a
  separate change and record the old/new version and the reason in WORKLOG.md.
- Don't let one scraper's failure crash the app or stop the other scrapers. Each
  scraper catches and logs its own errors, then returns an empty result.
- Don't add new project references to paths outside the repo. Third-party source goes
  under `External/<name>/` with an `UPSTREAM.md` recording source, commit and licence.
- Don't change `MyVideosDBVersion` or delete DB patch files without an explicit request.
