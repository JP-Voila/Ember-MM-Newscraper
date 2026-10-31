# Settings: dev-build defaults

What a **fresh profile** of the current build has switched on and off. Settings drive
which code paths run, so tests and bug reproductions depend on them. Generated
2026-11-01 from the code, not from the settings screens:

- **Core settings** (834 properties, 1552 values): `tools/Export-DefaultSettings.ps1`
  loads the built `EmberAPI.dll` into an empty profile and saves. Output goes to
  git-ignored `docs/tmp/defaults/` (`Settings.default.xml` + a flat `path = value`
  listing for grep/diff). Re-run it after any change to `clsAPISettings.vb` defaults.
- **Module on/off and order:** read from the dev profile's `Settings.xml`
  `<EmberModules>`, which the running app writes on first start. The owner made no module
  changes.

The owner reports changing nothing in the installed 1.11.1 except adding sources, so these
defaults are also the best picture of the owner's setup, **with one known exception
(§4)**.

---

## 1. Modules and scrapers

`On` = enabled on a fresh profile. Data scrapers run in `Order` (lowest first). Image,
theme and trailer scrapers all contribute candidates.

### Generic modules

| Module (assembly) | On | Notes |
|---|---|---|
| generic.EmberCore.BulkRename | ✅ | Renamer. Also hooks scrape/edit events |
| generic.EmberCore.ContextMenu | ✅ | Explorer context menu |
| generic.EmberCore.FilterEditor | ✅ | Media List Editor |
| generic.EmberCore.Mapping | ✅ | |
| generic.EmberCore.MediaFileManager | ✅ | Copy To / Move To |
| generic.EmberCore.MediaSources | ✅ | VideoSourceMapping project |
| generic.EmberCore.MetadataEditor | ✅ | Codec mapping |
| generic.EmberCore.MovieExporter | ✅ | |
| generic.Interface.Kodi | ❌ | |
| generic.Interface.Trakt | ❌ | |

### Movies

| Kind | On (order) | Off (order) |
|---|---|---|
| Data | **TMDB (4)** | IMDB (0), MoviepilotDE (1), OFDB (2), OMDb (3), Trakttv (5) |
| Image | FanartTV (0), TMDB (1) | — |
| Trailer | **TMDB (0)** | Apple (1), Davestrailerpage (2), VideobusterDE (3), YouTube (4) |
| Theme | **TelevisionTunes (0)** | YouTube (1) |

### Movie sets

| Kind | On | Off |
|---|---|---|
| Data | TMDB | — |
| Image | FanartTV, TMDB | — |

### TV

| Kind | On (order) | Off (order) |
|---|---|---|
| Data | **TVDB (4)** | IMDB (0), OMDb (1), **TMDB (2)**, Trakttv (3) |
| Image | FanartTV (0), TMDB (1), TVDB (2) | — |
| Theme | — | TelevisionTunes (0), YouTube (1) |

**Implications:**
- Movie data comes from TMDB only. The movie theme scraper that is on (TelevisionTunes)
  is an HTML scraper, likely broken (INVENTORY §3).
- The only trailer source is TMDB → YouTube (BUG-003).
- TV data comes from **TVDB only**, the legacy XML API whose status is still unconfirmed
  (WORKLOG "TVDB investigation"). TMDB is off for TV.

## 2. Behaviour defaults that matter for testing and the open bugs

| Setting | Default | Effect |
|---|---|---|
| `MovieScraperMetaDataScan` / `TVScraperMetaDataScan` | **true** | MediaInfo runs on scrape. Turn **off** in the test profile: `testlib` files are dummies |
| `MovieImagesDisplayImageSelect` / `MovieSetImagesDisplayImageSelect` / `TVImagesDisplayImageSelect` | true | A single manual scrape shows the image picker (BUG-008: opened from a worker thread) |
| `MovieScraperCollectionsAuto` | true | Movies are added to sets automatically from TMDB collections (BUG-004) |
| `MovieScraperCollectionsExtendedInfo` | **false** | NFO gets the plain `<set>Name</set>` form, not `<set><name>…</name><overview>…</overview></set>` (BUG-004) |
| `MovieScraperCollectionsYAMJCompatibleSets` | false | No `<sets>` block |
| `MovieSetUseMatrix` / `UseMSAA` / `UseExtended` / `UseExpert` | all false, all `MovieSetPath*` empty | No movie-set artwork/NFO files written to disk (`FileUtils.GetFilenameList.MovieSet` needs one of these plus a path). Sets live only in movie NFOs and the DB |
| `MovieScraperTrailer` | true | NFO trailer link scraped (TMDB data scraper → YouTube) |
| `MovieScraperTrailerFromTrailerScrapers` | false | The data scrape doesn't call trailer scrapers |
| `MovieScraperXBMCTrailerFormat` | true | Trailer link written in Kodi plugin URL form |
| `MovieScraperRatingDefaultType` / `TVScraperRatingDefaultType` | imdb / themoviedb | |
| `MovieScraperCert`, `TVScraperShowCert` | false | No certification scraped. `…CertCountry` is empty in pure defaults; the app sets it to `[All]` on first run |
| `TVScraperIdDefaultType` | tvdb | TVDB id is the show's primary id |
| `TVScraperOptionsOrdering` | Standard | Episode numbering (not DVD/absolute) |
| `TVEpisodeNoFilter` | true | |
| `TVEpisodeProperCase` | true | |
| `TVGeneralIgnoreLastScan` | true | |
| `TVMultiPartMatching` | `^[-_ex]+([0-9]+(?:(?:[a-i]\|\.[1-9])(?![0-9]))?)` | Multi-episode file matching (`testlib` has `S01E03E04`) |
| `MovieSkipLessThan` / `TVSkipLessThan` | 0 | No minimum file size: dummy files are scanned |
| `GeneralSourceFromFolder` | false | Video-source mapping uses the file name only |
| `GeneralOverwriteNfo` | false | |
| `MovieLock*` | all false | No field is locked |
| `MovieCleanDB` / `TVCleanDB` / `MovieSetCleanDB` | false | |
| `GeneralLanguage`, `MovieGeneralLanguage`, `TVGeneralLanguage` | en-US | |

## 3. File naming

Kodi **Frodo** naming is on for movies and TV (`MovieUseFrodo`, `TVUseFrodo` and the
per-artwork `…Frodo` flags = true). Eden, AD, Extended, NMJ, Boxee, YAMJ and Expert naming
are off. Movie sets: no naming scheme is on (§2). All NFO/image file names come from `FileUtils.GetFilenameList` under these flags.

## 4. Known differences from the owner's installed copy

| Item | Dev default | Owner's install | Evidence |
|---|---|---|---|
| TMDB as a **TV** data scraper | Off | **On** (runs before TVDB) | Owner log 2026-10-31: `[ScrapeData_TVEpisode] [Using] TMDB_Data`, then `TVDB_Data` |

To reproduce owner bugs on TV data (e.g. BUG-001), enable TMDB for TV in the test profile.
The installed 1.11.1 was built from an earlier commit (BUG-009), so other defaults may
differ too. Running `tools/Export-DefaultSettings.ps1 -BuildDir <install dir>` against
the installed `EmberAPI.dll` would list them.

## 5. Values the app sets on first run (not in pure defaults)

Seen in the dev profile after the first start, and not changed by the owner:
`MovieScraperCertCountry` and `TVScraperShowCertCountry` → `[All]`, `ProxyPort` →
`-1`.

## 6. Not covered here

`AdvancedSettings.xml` (addon-specific settings: per-scraper options, API keys, video
source mapping, format converters). Defaults ship in `EmberAPI/Defaults/` and in each
addon's code. Add a section when a bug touches them.
