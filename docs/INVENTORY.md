# Inventory

What every part of the project does today, how the parts fit together, and where a change
can be made in isolation and rolled back. Written 2026-10-31 from the source (not from
upstream docs). `file:line` references drift; re-check before relying on them.

Companion docs: [CLAUDE.md](../CLAUDE.md) (rules), [WORKLOG.md](WORKLOG.md) (status),
[BUGS.md](BUGS.md) (bugs).

---

## 1. The big picture

```
EmberMediaManager.exe  (WinForms: frmMain + dlg*)
        │  references
        ▼
EmberAPI.dll  ◄────────────── every addon references only EmberAPI
  data model, DB, NFO, images, scanner, settings, HTTP, YouTube, ModulesManager
        ▲
        │  Assembly.LoadFile at startup (no compile-time link from the app to addons)
Modules\<addon>\*.dll   ── scrapers (Data/Image/Trailer/Theme) + generic modules
        │
        ├─ scraper.Data.TVDB / scraper.Image.TVDB ─► TVDB.dll (External/TheTVDBApi)
        └─ generic.Interface.Kodi ─────────────────► KodiAPI.dll
```

- The app knows addons only through the interfaces in `EmberAPI/clsAPIInterfaces.vb`.
- An addon never calls another addon. Results pass between scrapers through the
  `Database.DBElement` that `ModulesManager` hands to each one in turn. One exception
  at the file level: the Trakt addon reads Kodi's settings file `Interface.Kodi.xml`
  (`dlgTrakttvManager.vb:289-291`).
- Everything shared lives in EmberAPI. A change there affects the app **and** every addon.

## 2. Projects

### In the solution (32: the app, EmberAPI, TVDB, KodiAPI + 28 addons)

| Project | Folder | Role | Extra refs / packages |
|---|---|---|---|
| EmberMediaManager | `EmberMediaManager/` | The exe: main window, all dialogs | EmberAPI |
| EmberAPI | `EmberAPI/` | Core library (see §4) | SQLite 1.0.115.5, NLog 4.7.14, Newtonsoft 13, **VideoLibrary 3.1.9** (YouTube), NiL.JS |
| TVDB | `External/TheTVDBApi/src/TVDB/` | Vendored C# client for TheTVDB **legacy XML API** | — (net4.5) |
| KodiAPI | `KodiAPI/` | C# Kodi JSON-RPC client | Newtonsoft 13 (net4.5) |
| *Addons* | `Addons/…` | 28 addon projects, see §3 | each refs EmberAPI |

### On disk but **not** in the solution (dead; not built)

| Project | Why it's dead |
|---|---|
| `Addons/scraper.EmberCore.XML` | net3.5; implements `EmberMovieScraperModule`, which no longer exists |
| `Addons/scraper.TVDB.Poster/scraper.TVDB.Data.vbproj` | net4.5, NLog 3.1, SQLite 1.0.93; implements removed `ScraperModule_TV`. Superseded by `scraper.Data.TVDB` + `scraper.Image.TVDB` |
| `Trakttv/` (C#) | Not referenced. The Trakt addons use the `Trakt.NET` 1.1.1 NuGet package instead |
| `EmberAPI_Test/` | Stale MSTest project (see CLAUDE.md) |

Deleting these would be a pure clean-up with no runtime effect. Not done yet.

### Build output

`<repo>\EmberMM - <Config> - <Platform>\`. Every `OutputPath` is `..\` (or `..\..\` for
addons) relative to its project, which resolves to the repo root, and `EmberMM*/` is
git-ignored. Each addon builds into
`Modules\<lower-case project name>\`, with two exceptions:
- **`scraper.Trailer.TMDB` and `scraper.Image.TMDB` share
  `Modules\scraper.image.tmdb\`.** Harmless (both use TMDbLib), but removing one folder
  removes both.
- `generic.EmberCore.BulkRename` builds into `Modules\generic.embercore.bulkrenamer\`.

Every addon's `OutputPath` matches its own `Configuration|Platform`. The solution maps
configurations 1:1, except `TVDB.csproj`, which always builds as `Any CPU`.

**Assembly names differ from project names** for some addons:
- FilterEditor → `generic.EmberCore.FilterEditor`
- VideoSourceMapping → `generic.EmberCore.MediaSources`
- Trakt interface → `generic.Interface.Trakt`

Enable/order settings in `Settings.xml` are keyed by **assembly** name, so renaming an
assembly loses those settings.

## 3. Addons

All live in `Addons/`. **Folder name ≠ project name** in places; the solution is the
source of truth.

### Scrapers

Data scrapers run **in order**. Each one fills only fields that are selected, empty and
not locked. Image/theme/trailer scrapers each return candidate lists, and the user (or
auto-select) picks from them.

| Addon (folder) | Implements | Source | Kind of client | Notes |
|---|---|---|---|---|
| scraper.TMDB.Data | Data: Movie, MovieSet, TV | TMDB | TMDbLib 1.9.1 (API) | Only data scraper for movie sets, and the **only one that scrapes seasons**. Episodes/seasons need a show TMDB ID, or a TVDB ID it converts (`TMDB_Data.vb:831`); with neither it aborts (BUG-001). Also fetches the NFO trailer link through EmberAPI `YouTube` |
| scraper.IMDB.Data | Data: Movie, TV | IMDB | HtmlAgilityPack (**HTML scrape**) | Likely broken by site changes. `Scraper_TVSeason` is a stub |
| scraper.Data.OMDb | Data: Movie, TV | OMDb | MovieCollection.OpenMovieDatabase (API) | **Ratings only** (movies and TV shows), needs an IMDb ID. Episode/season code commented out |
| scraper.Trakttv.Data | Data: Movie, TV | Trakt.tv | Trakt.NET 1.1.1 | `Scraper_TVSeason` is a stub |
| scraper.Data.TVDB | Data: TV | TheTVDB | TVDB.dll (legacy XML) | `Scraper_TVSeason` is a stub. Show search: IMDb lookup first, title search in auto modes, `dlgTVDBSearchResults` on single scrape (`TVDB_Data.vb:259-299`). Episode scrape with no show TVDB ID returns an empty container instead of `Nothing` (`:316-332`) |
| scraper.MoviepilotDE.Data | Data: Movie | moviepilot.de | HTML scrape | German |
| scraper.OFDB.Data | Data: Movie | ofdb.de | HTML scrape | German |
| scraper.TMDB.Poster | Image: Movie, MovieSet, TV | TMDB | TMDbLib | |
| scraper.FanartTV.Poster | Image: Movie, MovieSet, TV | Fanart.tv | FanartTv 2.0.5 | |
| scraper.Image.TVDB | Image: TV | TheTVDB | TVDB.dll | |
| scraper.TMDB.Trailer | Trailer: Movie | TMDB → **YouTube** | TMDbLib + EmberAPI `YouTube` | Every trailer is resolved through VideoLibrary (BUG-003) |
| scraper.Trailer.YouTube | Trailer: Movie | YouTube search | EmberAPI `YouTube` | |
| scraper.Apple.Trailer | Trailer: Movie | trailers.apple.com | JSON endpoint (`quickfind.php`) | **Site closed 2023 — dead** |
| scraper.Davestrailerpage.Trailer | Trailer: Movie | davestrailerpage.co.uk | HtmlAgilityPack | Likely broken |
| scraper.Trailer.VideobusterDE | Trailer: Movie | videobuster.de | HtmlAgilityPack | Likely broken |
| scraper.Theme.YouTube | Theme: Movie, TV | YouTube | EmberAPI `YouTube` | |
| scraper.TelevisionTunes.Theme | Theme: Movie, TV | televisiontunes.com | HTML | Likely broken |

### Generic modules

Generic modules hook into app events (`Enums.ModuleEventType`, `EmberAPI/clsAPICommon.vb`)
and/or add menus and settings panels. `Generic` = adds UI only.

| Addon (folder) | Name in UI | What it does | Hooks beyond UI |
|---|---|---|---|
| generic.EmberCore.BulkRename | Renamer | Renames files/folders from patterns, manually or after scraping | AfterEdit_*, ScraperMulti/Single_*, DuringUpdateDB_TV |
| generic.EmberCore.ContextMenu | Context Menu | Windows Explorer shell context menu (registry): "add folder as movie / TV source", "scan folder for new content" | — |
| generic.EmberCore.FilterEditor | Media List Editor | Custom media lists / custom tabs built from DB queries | — |
| generic.EmberCore.Mapping | MappingManager | Edit genre/country/certification/studio/status mappings (`Core.Mapping.*.xml`) | — |
| generic.EmberCore.MediaFileManager | (Media File Manager) | "Copy To" and **"Move To"** for selected movies/shows to configured folders (Move changes media on disk) | — |
| generic.EmberCore.MovieExport | MovieListExporter | Export the movie list via HTML templates | CommandLine |
| generic.EmberCore.TagManager | Tag Manager | Manage tags across the library. **Does not compile at HEAD**: superseded upstream (d08f4dae) by the in-app Tools → Tag Manager (`EmberMediaManager/dlgTagManager.vb`) | CommandLine |
| generic.EmberCore.VideoSourceMapping | Media Sources Editor | Assign a video source label (BluRay, DVD, …) by file extension or search string | — |
| generic.Embercore.MetadataEditor | Audio & Video Codec Mapping | Codec name mapping for media info | — |
| generic.Interface.Kodi | Kodi | Push changes to Kodi hosts over JSON-RPC (sync, remove, notify). **Owner does not use it** | BeforeEdit_Movie/TVEpisode, Remove_*, ScraperMulti/Single_*, Sync_* (`Interface.Kodi.vb:104-124`). It *raises* AfterEdit events but doesn't subscribe to them |
| generic.Interface.Trakttv | Trakt.tv Manager | Sync watched state/ratings with Trakt | BeforeEdit_Movie/TVEpisode/TVShow, Remove_*, ScraperMulti/Single_*, CommandLine (`Interface.Trakt.vb:76-95`) |

Core (`generic.EmberCore.*`) modules are enabled by default when no setting exists. The
check is a case-sensitive `AssemblyFileName.Contains("generic.EmberCore")`
(`clsAPIModules.vb:287`).

## 4. EmberAPI (core library)

Biggest files first. "Type" is the top-level class **or namespace** (`MediaContainers`,
`FileUtils`, `FFmpeg` and `YouTube` are namespaces; the YouTube class is
`YouTube.Scraper`).

| File | Type | Responsibility |
|---|---|---|
| clsAPIMaster.vb (small) | `Master` | Global state: `SettingsPath` (default `Profiles\Default`), `TempPath`, `eSettings`, `eLang`, `DB`, `appArgs` |
| clsAPILocalization.vb (8.7k) | `Localization` | ISO-3166 country and ISO-639 language tables (`CountryList`, `LanguageList`). **Not** UI translation: `Master.eLang.GetString` lives in `XML Serialization/clsXmlTranslations.vb` |
| clsAPIDatabase.vb (6.3k) | `Database` | All SQLite access. `Load_*`, `Save_*`, `Delete_*` per content type. Schema create/upgrade. `DBElement` (the in-memory record passed everywhere) |
| clsAPIMediaContainers.vb (5k) | `MediaContainers` | Data model: `Movie`, `TVShow`, `EpisodeDetails`, `SeasonDetails`, `MoviesetContainer`, images, media files. XML attributes here **define the NFO format** |
| clsAPIImages.vb (3k) | `Images` | Image download, select, save, delete. `SetPreferredImages` |
| clsAPIFileUtils.vb (2.7k) | `FileUtils` | Path/filename rules (`GetFilenameList` decides every output file name), online checks, file ops |
| clsAPINFO.vb (2.5k) | `NFO` | NFO read/write. **Merges scraper results** (`MergeDataScraperResults_*`) |
| clsAPIModules.vb (2.2k) | `ModulesManager` | Loads addons (`Assembly.LoadFile` on **every** dll in each module folder, third-party ones included), persists enable/order, runs the scraper chains (`ScrapeData_*`, `ScrapeImage_*`, `ScrapeTrailer_Movie`, `ScrapeTheme_*`) and `RunGeneric` hooks |
| clsAPISettings.vb (2k) | `Settings` | `Settings.xml` model + defaults |
| clsAPIScanner.vb (1.9k) | `Scanner` | Folder scan, file detection, episode regex matching, "Update Library" |
| clsAPICommon.vb (1.8k) | `Containers`, `Enums`, `Functions`, `Structures` (4 classes) | Shared enums (content types, scrape types, modifiers, event types), scrape option structs |
| clsAPITaskManager.vb (1.3k) | `TaskManager` | Background task queue |
| clsAPIMediaInfo.vb / clsAPIFFmpeg.vb | `MediaInfo`, `FFmpeg` | Stream info and frame extraction via external tools in `Bin\` |
| clsAPIStringUtils.vb | `StringUtils` | Title cleaning (`ApplyFilters` — BUG-002), sorting, URL conversions |
| clsAPIImageUtils.vb | `ImageUtils` | Bitmap helpers |
| clsAPIYouTube.vb | `YouTube.Scraper` | Video details/search through **VideoLibrary**. Used by: the TMDB trailer scraper, the TMDB data scraper (NFO trailer link, `scraper.TMDB.Data/Scraper/clsScrapeTMDB.vb:548`), the YouTube trailer/theme scrapers, and the manual media-file dialog |
| clsAPIHTTP.vb | `HTTP` | Download helper for scrapers/images |
| clsAPIXML.vb | `APIXML` | Loads the `Core.*.xml` mapping/language files |
| clsAPIAdvancedSettings.vb | `AdvancedSettings` | Key/value store (`AdvancedSettings.xml`) used by **addons for their own settings** |
| clsAPICommandLine.vb | `CommandLine` | CLI switches (`-scrapemovies`, `-updatetvshows`, `-profile <name>`, `-nowindow`, …) |
| clsAPIProfiles.vb | `Profiles` | Profile folders under `Profiles\` |
| clsAPIDVD*.vb, MediaStub, MediaFiles, Notifications, NumUtils, FormsUtils; clsAPISorter.vb (`ListViewColumnSorter`) | — | Small helpers |
| `XML Serialization/` | — | Serializers for AdvancedSettings, mappings, ratings, languages, translations |
| `DB/` | — | `MyVideosDBSQL.txt` (fresh schema) + `MyVideosDBSQL_v<N>_Patch.xml` upgrades |
| `Defaults/`, `Translations/` | — | Shipped default config files and en-US strings |

## 5. EmberMediaManager (the exe)

| File | Responsibility |
|---|---|
| frmMain.vb (19k) | Main window, list views, filters, menus. Its `Load` handler does the startup work (DB, modules; see §6). Registers an `AssemblyResolve` handler (`MyResolveEventHandler`, ~line 355). **Scrape orchestration**: `Scraper_CreateList_*` (build the job list from selection + modifiers), `Scraper_DoWork_*` (background worker per content type, ~line 15130+), `Scraper_RunWorkerCompleted_*` (opens the edit dialog for single scrapes) |
| dlgSettings.vb (8.5k) | Settings dialog; panels from addons are injected via `InjectSetup*` |
| dlgEdit_Movie / Movieset / TVShow / TVSeason / TVEpisode | Per-type edit dialogs (where manual set membership is changed) |
| dlgImgSelect.vb | Image picker for single scrapes |
| dlgMediaFileSelect.vb | Trailer/theme picker (calls `YouTube.Scraper` directly) |
| dlgOfflineHolder, dlgCustomScraper, dlgTagManager, dlgSource*, … | Other dialogs |
| clsTheming.vb | Info-panel theming from `Themes\` |
| ApplicationEvents.vb | Startup: splash, InstallTasks, profile selection (`-profile`), `Settings.Load`, `APIXML.CacheXMLs`, then constructs `frmMain`. Does **not** load modules |

## 6. Key flows

### Startup
1. `ApplicationEvents`: splash → InstallTasks → pick profile (`Master.SettingsPath`) →
   load `Settings.xml` → `APIXML.CacheXMLs` → construct `frmMain`.
2. `frmMain.Load` (~line 357-391): `AdvancedSettings.Start` → default options → **open the
   DB** (`Connect_MyVideos`, upgrading if needed) → `ModulesManager.LoadAllModules`.
3. Modules load **on a background worker**: scan `Modules\*\*.dll`, instantiate every
   type implementing an interface, apply enable/order from `Settings.EmberModules`.
   Scrape calls wait on `ModulesLoaded` until it finishes.

### Update Library (scan)
`Scanner` walks the configured sources → detects movies/shows/episodes (episode regexes,
title filters `StringUtils.ApplyFilters`) → reads any existing NFO → `Database.Save_*`.
- **Movies are not scraped online here.**
- **TV is, partly.** A *new* episode without an NFO, whose show *already has* IDs, is run
  through `ScrapeData_TVEpisode`. New seasons go through `ScrapeData_TVSeason` the same
  way (`clsAPIScanner.vb:800-809, 1029-1031`).
- A brand-new show has no IDs yet, so its episodes come in unscraped.

### Scrape (any content type)
1. `frmMain.Scraper_CreateList_*` builds `ScrapeItem`s (DB row + `ScrapeModifiers` =
   which parts: NFO, poster, fanart, trailer, …) and starts the worker.
2. `Scraper_DoWork_*` per item:
   - `Master.DB.Load_*` → `DBElement`
   - `ModulesManager.ScrapeData_*`: **one** deep clone of the element is passed through
     all enabled data scrapers in order. After each one, the IDs, title and year it
     found are copied into the clone so the next scraper can use them. All results are
     then merged by `NFO.MergeDataScraperResults_*`, honouring field locks and global
     options.
   - Optional: if `MovieScraperTrailerFromTrailerScrapers` is set, `ScrapeData_Movie`
     calls the trailer scrapers itself for the NFO trailer link
     (`clsAPIModules.vb:973-987`).
   - optional `MediaInfo` scan
   - `ModulesManager.ScrapeImage_*` (+ trailer/theme) → candidate lists. `dlgImgSelect`
     appears only for `SingleScrape` **and** when the `*ImagesDisplayImageSelect` setting
     is on; otherwise `Images.SetPreferredImages` picks automatically. Image and trailer
     pickers are opened from inside `DoWork`, the background thread.
   - **Every scrape type except `SingleScrape`** (including `SingleAuto` and
     `SingleField`): `RunGeneric(ScraperMulti_*)`, then `Master.DB.Save_*` immediately.
   - **`SingleScrape`:** `RunWorkerCompleted` opens the edit dialog; saving happens when
     the user clicks OK.
3. TV shows: `ScrapeData_TVShow` searches for the show first (each scraper its own way),
   stores the IDs, then seasons/episodes use them. **Episodes and seasons never search on
   their own.**

### Save (`Database.Save_Movie` as the model; others are similar)
A transaction is opened only when `Not batchMode` (`clsAPIDatabase.vb:3268`). Then:
1. If `toNfo`, write the `.nfo` next to the media (`NFO.SaveToNFO_*`). If `toDisk`, save
   images, theme and trailer to disk. These come **first**, because they supply the file
   paths stored in the row (~`:3487-3492`).
2. Write the main movie row, then the link rows (actors, genres, …).
3. Movie-set links: `Set_MoviesetsForMovie`, and if that changed anything, rewrite the
   NFO (~`:3632`).
4. Commit. If `doSync`, `RunGeneric(Sync_*)` (Kodi/Trakt addons).

**Disk writes happen before the DB commit, and there is no rollback in `Save_Movie`.** If
anything fails part-way, files on disk and the DB disagree.

### Generic hooks
`ModulesManager.RunGeneric(eventType, …)` calls every enabled generic module whose
`ModuleType` includes that event. List of events: `Enums.ModuleEventType`.

## 7. Persistent state

### Per profile (`<install>\Profiles\<name>\`, = `Master.SettingsPath`)

| File | Content | Written by |
|---|---|---|
| `MyVideos48.emm` | SQLite library DB | `Database` |
| `Settings.xml` | All core settings + addon enable/order (`EmberModules`) | `Settings`, `ModulesManager.SaveSettings` |
| `AdvancedSettings.xml` | Addon-specific settings (key/value) | addons via `AdvancedSettings.*` |
| `Core.Mapping.{Certifications,Countries,Editions,Genres,Status,Studios}.xml`, `Core.Languages.Scrapers.xml`, `Ratings.xml` | Mappings and scraper languages. Legacy `Core.Genres.xml` / `Core.ScraperLanguages.xml` are migrated on load (`clsAPIXML.vb:33-41,101-102`) | Mapping addon / `APIXML` |
| `Interface.Kodi.xml`, `Interface.Trakt.xml` | Kodi hosts / Trakt account for the interface addons (Trakt also reads the Kodi file) | those addons |
| `Templates\`, `Themes\` | **Custom** export templates and info-panel themes. Defaults ship in `<install>\Themes` and `<install>\Modules\generic.embercore.movieexporter\Templates` | — |

### Per install (`<install>\`)
`Modules\` (addons), `Bin\` (FFmpeg/MediaInfo), `Profiles\profiles.xml`, `Temp\`
(scratch, incl. TVDB `Temp\Shows\loaded.zip`), `Log\<yyyy-MM-dd>.csv`.

### On the owner's media drive
`.nfo` files, images (poster/fanart/banner/…), trailers, themes, next to each video.
File names come from `FileUtils.GetFilenameList` + the naming settings. **This is the only
state Kodi sees**, and the only state with no backup by default.

## 8. Change seams — how to make a change modular and reversible

From most isolated to least:

| Where the change lives | Blast radius | How to roll back |
|---|---|---|
| **One addon** (scraper/generic) | Only that addon. App and other addons untouched | Revert the commit, or swap that one `Modules\<addon>\` folder back. Or disable it in Settings (no code change at all) |
| **Vendored lib** (`External/TheTVDBApi`) | The two TVDB addons | Revert; log in `UPSTREAM.md` |
| **A new setting** that switches new behaviour on, default = old behaviour | Off by default ⇒ no change until enabled | Untick it. Adding a setting is safe; renaming/removing one loses the stored value |
| **EmberAPI internals** (no signature change) | App + every addon that calls it | Revert and rebuild everything (EmberAPI.dll is shared) |
| **EmberAPI public signature / data model** | Every caller; NFO/DB format if it's a serialized field | Revert + rebuild all; follow the CLAUDE.md "adding a property" checklist |
| **`clsAPIInterfaces.vb`** | **Every addon must change in the same commit** | Revert all together. Avoid |
| **frmMain orchestration** | All scraping for that content type | Revert; huge file, keep the diff tiny |
| **DB schema** | One-way upgrade of the owner's library | Old `MyVideos48.emm` is kept (the upgrade copies to a new file), so rollback = run the old exe. **But** some upgrade steps rewrite NFOs on disk (e.g. pre-v43 patches, `clsAPIDatabase.vb` ~`:5217`, `:5649-5683`), and the old exe can't undo that. Avoid for bug fixes |
| **NFO/image output** (`NFO`, `MediaContainers` XML attrs, `FileUtils` naming) | Files on the owner's disk + what Kodi shows | **Not reversible by git**: rewritten files stay rewritten. Test on copies |

### Practical rules for this project

1. **One bug = one commit (or one small branch)**, touching the fewest seams above. Put
   the BUG-NNN in the commit message so a fix can be found and reverted on its own.
2. Prefer fixing inside the addon over fixing in EmberAPI, and EmberAPI over frmMain,
   when either would close the defect.
3. **The dev build is already isolated from the installed copy.** It runs from
   `<repo>\EmberMM - Debug - x64\` with its own `Profiles\`, DB and settings (profiles
   resolve relative to the exe). What can still be shared:
   - **media folders**: point the dev profile's sources at a small test folder with
     copied media (and copied NFOs/images) before testing anything that saves;
   - **online accounts**: if the dev profile is a *copy* of the real one, it carries
     the Trakt account (`Interface.Trakt.xml`) and Kodi hosts (`Interface.Kodi.xml`).
     Trakt/Kodi hooks would then act on the real services. Disable those addons in the
     dev profile.
4. Before testing a build against the real library: copy the profile folder
   (`Profiles\<name>\`) — that is the DB plus all settings in one place.
5. Disable instead of delete: a broken scraper is switched off in Settings; the code stays
   until removal is a decided, separate change.

## 9. Known oddities found during this inventory

- Four projects on disk that the solution doesn't build (§2).
- TMDB trailer + image addons share one output folder (§2).
- Several HTML-scraping addons are probably broken by site changes, and Apple trailers is
  certainly dead (§3).
- Disk writes happen inside the DB transaction but aren't rolled back with it (§6).
- `MoviesetContainer.Create_SetNode_Kodi` writes only the first set into the NFO
  (BUG-004).
- Newtonsoft.Json versions differ between addons (12.0.3 in the Trakt addons, 13.0.1
  elsewhere). The exe's `app.config` redirects 0.0.0.0–13.0.0.0 → 13.0.0.0, and
  `LoadModules` loads every dll in each module folder, so version clashes resolve at
  runtime. Don't "align" the versions as a side effect.
- Season scraping is a stub in every TV data scraper except TMDB (§3).
- Image and trailer pickers are shown from a background worker thread (§6).
- Verified 2026-10-31 by an independent pass against the source: about 140 claims
  checked, corrections applied. Live-site status (which HTML scrapers are broken) has
  not been checked.
