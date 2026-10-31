# CLAUDE.md

Guidance for AI coding agents (Claude Code and others) working in this repository.
Read this before touching any code. See also [SECURITY.md](SECURITY.md).

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
  build `Debug|x64` (or x86). Output goes to `..\EmberMM - <Config> - <Platform>\`
  (a sibling of the repo folder, not inside it); addons build into its `Modules\` subfolder.
- **External project dependency:** the solution references
  `..\TheTVDBApi\src\TVDB\TVDB.csproj`, which lives *outside* this repo (a sibling clone).
  `scraper.Data.TVDB` and `scraper.Image.TVDB` will not build without it.
- `EmberAPI_Test` is an MSTest project that is **not included in the solution** and is
  largely stale (references NLog 3.1 / `UnitTestFramework` 10.x). Don't rely on it; if you
  add tests, say so and note they have not been run.

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
KodiAPI/                    C# Kodi JSON-RPC client library
Trakttv/                    C# Trakt.tv API client library
BuildSetup/                 Installer scripts and Transifex download tooling
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

## Workflow for bug fixes

1. Get a precise symptom from the owner (steps, content type, which scraper, log excerpt
   from `<install dir>\Log\<yyyy-MM-dd>.csv` — NLog config in `EmberAPI/NLog.config`).
2. Locate the code path — grep for the localized message text or the UI control name;
   `frmMain.vb` and `clsAPIDatabase.vb` are huge, so search rather than read top-down.
3. Explain the root cause before changing code.
4. Make the smallest fix that addresses it. Check all call sites of anything you touch.
5. Summarise: root cause, the change, risk, and a manual test plan for Windows.
6. Optionally add an entry to `Changelog.txt` if the owner wants one.

Many "bugs" in a 2022-era scraper app are really **upstream API changes** (sites changed
HTML, APIs deprecated/versioned, endpoints moved, keys revoked). Check that first for any
scraper failure — e.g. HTML-scraping addons (IMDB, OFDB, Moviepilot, Videobuster,
Apple trailers, Dave's trailer page, TelevisionTunes) are the most likely to be broken.

## Things not to do

- Don't commit secrets, API keys, personal media paths, `Settings.xml`, databases
  (`*.emm`) or log files. See SECURITY.md about the API keys already in the source.
- Don't upgrade NuGet packages or retarget frameworks as a side effect of a bug fix.
- Don't add new project references to paths outside the repo.
- Don't change `MyVideosDBVersion` or delete DB patch files without an explicit request.
