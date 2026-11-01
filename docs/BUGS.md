# Bug log

Bugs ("niggles") found by the owner in the current executable, plus bugs found
incidentally while working on something else (marked **Found by:** code reading / build /
log). Each entry: symptom, steps, status, and findings once investigated. Session-level
progress goes in [WORKLOG.md](WORKLOG.md).

Status values: `open` (reported, not investigated), `investigating`, `fixed` (with
commit), `wontfix`.

---

## BUG-001 — Scraping a single episode of a new show returns blank show data

- **Reported:** 2026-10-31
- **Status:** investigating (root cause found, not fixed)
- **Content type:** TV show / episode
- **Scrapers enabled:** TMDB; TVDB for episode data (see WORKLOG "Owner's setup")

**Symptom.** Scraping one episode of a show that has never been scraped opens the
show-level flow (poster art selection, confirm details), but every field is empty.
No usable episode data is scraped.

**Steps.**
1. Add a new show to a source, run *Update Library*.
2. Select a single episode of that show and scrape it. Repeat once (same result).
3. Scrape the whole show from the top level. Episode data is then scraped correctly.

**Workaround.** Scrape the show from the top level first.

**Log.** Trimmed copy at `docs/tmp/2026-10-31.csv` (git-ignored; not committed). Show:
*Marvel's What If [2021]*, episode S01E01, scraped at 05:18 and again at 10:06.

```
[TMDB_Data] [Scraper_TVEpisode] [Abort] No TV Show TMDB ID available
[TVDB_Data] [Scraper_TVEpisode] [Start]  →  [Done]          (silent skip, no TVDB ID)
NFO.MergeDataScraperResults_TVEpisode_Single  WARN  No valid episode or season number found
[TMDB_Image] [Scraper_TV] [Abort] No TMDB ID exist to search
[TVDB_Image] [Scraper] [Abort] No TVDB ID exist to search
```

**Root cause.** Episode scraping assumes the parent show has already been scraped.
Every TV episode scraper looks the episode up by the *show's* ID
(`TVShow.UniqueIDs.TMDbId` / `TVDbId`). A show that has only been added by
*Update Library* has no IDs yet, and the episode scrape path has no step that searches
for the show first. So every data and image scraper aborts, and frmMain still opens
the image-select and edit dialogs with nothing in them.

- `Addons/scraper.TMDB.Data/TMDB_Data.vb:850`: TMDB aborts without a show TMDB ID
  (it only converts from a TVDB ID if one exists, line 831).
- `Addons/scraper.Data.TVDB/TVDB_Data.vb:320`: TVDB skips without a show TVDB ID, but
  returns an empty `EpisodeDetails` instead of `Nothing` (line 316/332). That empty
  result is what produces the misleading "No valid episode or season number found"
  warning in `EmberAPI/clsAPINFO.vb:1166`.
- `EmberAPI/clsAPIModules.vb:1085` `ScrapeData_TVEpisode`: runs the episode scrapers
  directly. No show-ID check or show search.
- A top-level show scrape works because `ScrapeData_TVShow` searches by title, stores
  the IDs, then scrapes the episodes with them.

**L3 test run 1 (2026-11-01, dev build, TVDB only).** *The Expanse* S01E01, right-click →
(Re)Scrape episode: **nothing visible happens**, no dialog and no message. Log: TVDB
`Scraper_TVEpisode` `[Start]` → `[Done]` in under 1 ms (no HTTP), the same misleading
"No valid episode or season number found" warning, then `Canceled scraping`. The empty
dialogs in the owner's install come from the TMDB path; with TVDB alone the scrape is
cancelled silently. Same root cause. `testlib` unchanged (`git -C testlib status` clean).

**Fix options (not decided).**
1. Small: in the episode scrape path, if the show has neither a TMDB nor a TVDB ID,
   stop and tell the user to scrape the show first. No more empty dialogs.
2. Larger: run the show search/scrape automatically first, then continue with the
   episode. More convenient, but touches the frmMain task flow.
3. Either way: make `TVDB_Data.Scraper_TVEpisode` return `Nothing` when it skips, so the
   log stops showing the misleading warning.

---

## BUG-002 — TV show title filter regex fails on every show during Update Library

- **Reported:** 2026-10-31 (found in the BUG-001 log, not reported by the owner)
- **Status:** open
- **Content type:** TV show

**Symptom.** During *Update Library*, every TV show logs an `ERROR` from
`StringUtils.ApplyFilters`:

```
ArgumentException: parsing "(?i,[\W_]blu[\W_]?ray.*" - Unrecognized grouping construct.
```

**Findings so far.** The shipped defaults are correct: `"(?i)[\W_]blu[\W_]?ray.*"`
(`EmberAPI/clsAPISettings.vb:1789`, `1823`, `1852`). The broken pattern has `,` instead
of `)`, so it most likely comes from the owner's saved `Settings.xml` (TV show filters).
That is either a typo in the settings UI or a save/load bug. Not checked yet:

- the owner's TV show filter list in Settings (look for `(?i,`);
- whether `ApplyFilters` stops at the first bad pattern and skips the remaining filters,
  which would leave show titles unfiltered.

---

## BUG-003 — Trailer download no longer works

- **Reported:** 2026-10-31
- **Status:** open
- **Content type:** Movie

**Symptom.** Downloading trailers fails. No more detail yet.

**Owner's setup.** Only the **TMDB** trailer scraper is enabled; all others disabled.

**Code path (verified).** `scraper.TMDB.Trailer` gets the movie's video list from TMDB,
keeps entries with `Site = "YouTube"`, and resolves each one through
`YouTube.Scraper.GetVideoDetails(Video.Key)`
(`Addons/scraper.TMDB.Trailer/Scraper/clsScrapeTMDB.vb:93-94`). That calls the
`VideoLibrary` NuGet package 3.1.9 (libvideo), `_Client.GetAllVideosAsync(...)` in
`EmberAPI/clsAPIYouTube.vb:90`, to get the actual stream URLs. The manual trailer
dialog uses the same code (`EmberMediaManager/dlgMediaFileSelect.vb:261`).

**Likely cause (upstream, not yet confirmed by log).** YouTube changes its player
regularly and breaks old stream-extraction libraries; libvideo 3.1.9 dates from ~2021.
If so, TMDB still returns trailer keys, but every `GetVideoDetails` call fails or
returns no streams, so no trailer can be downloaded.

**Still useful from owner.** A log excerpt from one movie's trailer scrape (look for
`[TMDB_Trailer]` and any `ERROR` from `EmberAPI.YouTube`). Does the trailer list come up
empty, or does it fail on download?

**Other trailer scrapers (disabled, but likely also broken).**
- `scraper.Apple.Trailer` scrapes `trailers.apple.com`
  (`Addons/scraper.Apple.Trailer/Scraper/clsScrapeTrailerApple.vb:47`). Apple shut that
  site down in 2023, so this scraper is very likely dead.
- Davestrailerpage and VideobusterDE are HTML scrapers and may be broken too.

**Fix direction (to discuss).** Upgrading `VideoLibrary` is a package upgrade. CLAUDE.md
says not to do that as a side effect, so it needs an explicit decision. The current
libvideo may still not keep up with YouTube. The usual robust option is to call an
external `yt-dlp.exe`. Disable/remove the Apple scraper.

---

## BUG-004 — Movies not reliably grouped into Sets in Kodi

- **Reported:** 2026-10-31
- **Status:** open
- **Content type:** Movie / Movie set
- **Player:** Kodi on Android TV

**Symptom.** Grouping movies into sets is inconsistent. Sometimes it happens
automatically and sometimes not. Sometimes ~90% of a set's movies appear in the set and the
rest show as standalone movies. Unclear whether Ember or Kodi is at fault.

**Owner's follow-up.** Movies were added to sets **manually in Ember** (edit dialog),
then the Kodi library was refreshed. Not all of them showed up in their set. So it is
not clearly a Kodi-only problem.

**How it should work.** Kodi groups movies by the `<set>` element in each movie's NFO
(`<set><name>…</name><overview>…</overview></set>`), matching on the set **name**.
Movies whose NFO lacks `<set>`, or has a slightly different name, end up outside the set.

**To check (splits Ember vs Kodi).**
1. Pick a set with a stray movie. Open the stray movie's `.nfo` and one grouped movie's
   `.nfo` on disk and compare the `<set>` block (missing? name spelled differently?
   whitespace/punctuation?).
2. If the NFOs match → Kodi-side (library not refreshed for that file; on Kodi, "Refresh"
   the stray movie or rescan).
3. If the stray NFO is missing/different → Ember-side: find out whether the movie got
   its set from the TMDB scraper (automatic collection) or was added manually in Ember's
   set manager, and whether its NFO was rewritten afterwards.

**Findings so far.**
- Ember writes the set node in `MoviesetContainer.Create_SetNode_Kodi`
  (`EmberAPI/clsAPIMediaContainers.vb:2084`). It writes **only the first set**
  (`Items.Item(0)`) as `<set><name>…</name>…</set>` (extended info on) or
  `<set>Name</set>`. A movie in two sets gets only one in its NFO.
- Strong suspect on the Kodi side: Kodi's **Update library** adds new files but does not
  re-read the NFO of a movie already in the library. An edited NFO is only picked up
  when that movie is **Refreshed** in Kodi (Information → Refresh → use local info), or
  when Ember pushes the change through its Kodi interface addon
  (`generic.Interface.Kodi`, JSON-RPC). Which movies "updated" would then depend on
  whether Kodi happened to rescan each one.
- Owner confirmed the Kodi interface addon is **not** used: Kodi on the TV scans the
  library itself. Nothing pushes NFO changes to Kodi, so the refresh behaviour above
  fits.
- Pending (owner to test): after a manual set edit in Ember, does the stray movie's
  `.nfo` on disk contain the `<set>` block (step 1 below)?

**Code to look at once narrowed down.** NFO writing in `EmberAPI/clsAPINFO.vb` (set
section). The TMDB data scraper's collection handling and the "automatically add movies to
sets" settings. The movie-set DB linking in `EmberAPI/clsAPIDatabase.vb`.

---

## BUG-005 — Old Tag Manager addon no longer compiles

- **Reported:** 2026-10-31. **Found by:** first command-line build
- **Status:** **fixed** 2026-11-01: project removed from the solution (files kept on
  disk). Tag management now relies on the in-app Tag Manager; BUG-006 still to fix there.
- **Content type:** Movie / TV show tags

**Symptom.** `Addons/generic.EmberCore.TagManager` fails to build:
`'Save_Tag_Movie' is not a member of 'Database'` and `'Delete_Tag' …`
(`dlgTagManager.vb:498, 501, 504`).

**Findings.** Upstream commit `d08f4dae` (2022-11-27, "added: new Tag Manager") removed
those DB methods and built a replacement Tag Manager into the app itself:
`EmberMediaManager/dlgTagManager.vb`, wired to **Tools → Tag Manager**
(`frmMain.vb` ~16249). The old addon was left in the solution, broken. The owner's
installed 1.11.1 has a working Tag Manager, but it isn't known which of the two it is.

- The old addon also registers a `CommandLine` hook (`Module.Tag.vb:61`). The in-app one
  has no command-line equivalent.
- Owner wants a working Tag Manager. Options weighed: drop the old addon and rely on
  the in-app one, or port the addon to the current tag API. The owner chose to drop it
  (2026-11-01). The old addon was movies-only and its `CommandLine` hook was a no-op
  (`RunGeneric` returns an empty result), so nothing it offered is lost.
- To reverse: add `Addons\generic.EmberCore.TagManager\generic.EmberCore.TagManager.vbproj`
  back to the solution. It still won't compile without a port.

---

## BUG-006 — In-app Tag Manager: removing a tag from a movie/show is undone

- **Reported:** 2026-10-31. **Found by:** code reading. **Not reproduced yet.**
- **Status:** open
- **Content type:** Movie / TV show tags

**Suspected symptom.** In Tools → Tag Manager, untagging an item (moving it out of
"Tagged") and clicking OK leaves the tag on the item.

**Findings.** `EmberMediaManager/dlgTagManager.vb` `Process_Tags`, step 3 (unchanged,
not-deleted tags). Row states are `Unchanged` / `ToRemove` / `New`.
- Line ~382 removes the tag from rows in state `ToRemove`.
- Line ~384 then selects rows where state is **not** `Unchanged`. That includes
  `ToRemove` as well as `New`, and line ~385 adds the tag to all of them. So a removed
  tag is added straight back. The intended filter is presumably `= "New"`. Same pattern
  for TV shows at ~387-391.
- Step 2 (renamed tag, ~364-375) renames the tag on every row regardless of state, so a
  row marked `ToRemove` gets the new name instead of losing the tag.

**To confirm.** A unit test is hard (dialog). L3: tag two movies in the test library,
open Tag Manager, untag one, OK, then check the DB/NFO `<tag>` of both.

---

## BUG-007 — Saving writes NFO/images to disk before the DB commit, with no rollback

- **Reported:** 2026-10-31. **Found by:** code reading (INVENTORY verification)
- **Status:** open (latent; no reported symptom)
- **Content type:** all

**Findings.** `Database.Save_Movie` (`EmberAPI/clsAPIDatabase.vb` ~3264):
- It writes the `.nfo`, images, theme and trailer to disk *before* writing the DB row.
  It does this inside the transaction, which is only opened when `Not batchMode`.
- It has no `Rollback` path. If anything fails after the disk writes, the files on disk
  and the DB disagree (e.g. a new NFO for a row that was never saved).
- The other `Save_*` methods follow the same pattern; not yet checked one by one.

Low priority unless a symptom shows up. Don't change the order as a side effect of other
fixes: file paths written to the row come from the disk step.

---

## BUG-008 — Image/trailer picker dialogs are opened from a background thread

- **Reported:** 2026-10-31. **Found by:** code reading (INVENTORY verification)
- **Status:** open (latent; no reported symptom)
- **Content type:** all (single scrape)

**Findings.** On `SingleScrape`, `frmMain.Scraper_DoWork_*` (BackgroundWorker `DoWork`)
creates and shows `dlgImgSelect` / the trailer picker directly. Example:
`Scraper_DoWork_TVEpisode`, `frmMain.vb` ~15490; movies ~15284. WinForms UI should be
created on the UI thread. Doing it from a worker can cause dialogs behind the main
window, focus problems, or rare hangs/cross-thread exceptions. It may be related if the
owner ever sees a picker that "doesn't appear" or freezes.

---

## BUG-009 — Upstream HEAD did not compile

- **Reported:** 2026-10-31. **Found by:** first command-line build
- **Status:** **fixed** in `3da4d639` (plus `9297ff1b` for the build environment)

**Findings.** Upstream's last commits (2242d240, c7235061; Nov/Dec 2022) were an unfinished
cleanup. They removed `Imports System.Windows.Forms` and `Enums.ScraperEventType` from
`clsAPICommon.vb`, half-renamed `TableItem`, and renamed `APIXML.CacheXMLs` to
`CacheAllXml` without updating the caller. The fix restored those pieces with no
behaviour change.

**Implication.** The owner's installed 1.11.1 exe was built from an earlier commit. Its
behaviour can differ from this code in places. When a bug doesn't reproduce in the dev
build, check whether that code changed after the owner's build.

---

## BUG-010 — App crashes on start with a new profile: "Could not find file …\Settings.xml"

- **Reported:** 2026-11-01 (owner, first launch of the dev build)
- **Status:** **fixed**, see the commit `fixed: BUG-010 …`
- **Content type:** startup / settings

**Symptom.** Starting with a profile that has no `Settings.xml` yet (first run, or any new
profile) shows `Could not find file '…\Profiles\Default\Settings.xml'` and the app
terminates. Log: `MyApplication_UnhandledException` → `FileNotFoundException` at
`EmberAPI.Settings.Load()` `clsAPISettings.vb:line 1119`, called from
`ApplicationEvents.vb:line 149`.

**Root cause.** `Settings.Load` opened `New StreamReader(configpath)` on the first line,
*before* its `If File.Exists(configpath)` check and outside the `Try`. Introduced upstream
in `87736ca3` (2022-04-02, "fixed: new/updated settings.xml can't be saved…"), so any new
profile has crashed since then. Existing installs never hit it because their profile
already has the file.

**Fix.** Open the reader only if the file exists; close it only if it was opened.
2 lines changed in `clsAPISettings.vb`. No other behaviour change.

**Enumerate-first check.** Every other `New StreamReader(` in EmberAPI, the app and the
addons that runs at startup is already guarded by `File.Exists` and/or `Try`:
AdvancedSettings, Profiles, ScraperLanguages, Genre/Simple mappings, Kodi, Trakt.
`AdvancedSettings.SetDefaults` reads only shipped `Defaults\` files.

**Verification (no test project yet; L2-style scripts against the built `EmberAPI.dll`,
kept in the session scratchpad):**
- Repro: empty temp profile → `Settings.Load()`. Before the fix: threw
  `FileNotFoundException` (the owner's error). After: returns normally.
- Round trip: `Load` → set `MovieSkipLessThan = 7` (non-default) → `Save` → reset →
  `Load` gives `7`. Existing files still load and are really read.
- **To do:** port both as the first tests when the L2 test project exists.

**L4 for the owner.** Launch `EmberMM - Debug - x64\Ember Media Manager.exe` with
`Profiles\Default` empty. It should start, and `Settings.xml` should appear in that folder
after closing.

---

## BUG-011 — "Repair Settings.xml" can never succeed; falls back to all-default settings

- **Reported:** 2026-11-01. **Found by:** code reading (while fixing BUG-010)
- **Status:** open (latent)
- **Content type:** startup / settings

**Findings.** `Settings.Load` (`EmberAPI/clsAPISettings.vb` ~1117-1155). If deserializing
`Settings.xml` throws (e.g. an old enum value such as `PrefSize>Xlrg<`), the catch block
tries to repair the text. But it calls `xmlReader.ReadToEnd` on the **same stream** the
failed `Deserialize` already consumed, so it gets only the leftover tail, or nothing.
The repair regexes therefore never see the file. The second deserialize fails, the file is
copied to `Settings.xml_backup`, and **all settings reset to defaults**. Before
`87736ca3` the repair re-opened the file with its own reader.

**Impact.** Only when `Settings.xml` is damaged or from a much older version. The user
silently loses every setting (the backup file is kept).

**Likely fix.** Re-read the file (`File.ReadAllText(configpath)`) in the repair path.
Test: a `Settings.xml` containing `PrefSize>Xlrg<` should load with `Any`, not with
defaults.

---

## BUG-012 — TVDB show search always returns "No matches found"

- **Reported:** 2026-11-01. **Found by:** owner, L3 test run 1 (TVDB as the only TV data
  scraper, dev build)
- **Status:** investigating (root cause found: upstream API change)
- **Content type:** TV show
- **Scrapers enabled:** TVDB only (TV data)

**Symptom.** Scraping *Breaking Bad* from the top level opens the TVDB search dialog with
"No matches found". The show is never identified, so no data or images are scraped.

**Log** (`EmberMM - Debug - x64\Log\2026-11-01.csv`, 15:22:59–15:23:38). No `ERROR`: the
search path has no error logging at all, so its absence proves nothing.

```
[TVDB_Data] [Scraper_TV] [Start]
[TVDB_Data] [Scraper_TV] [Abort] [Cancelled] Cancelled by user        (owner closed the empty dialog)
[FanartTV_Image] / [TMDB_Image] / [TVDB_Image] ... [Abort] No TVDB ID exist to search: Breaking Bad
```

**Root cause.** TheTVDB's legacy XML API is only half retired. Probed directly on
2026-11-01 (curl, same URLs the vendored client builds):

| Legacy endpoint | Used by | Result |
|---|---|---|
| `/api/GetSeries.php?seriesname=…&language=en` | show search by name | **HTTP 200, `<Data></Data>`: empty for every query** (`Breaking Bad`, `Breaking`, `Expanse`) |
| `/api/{key}/series/81189/en.xml` | — | works (Breaking Bad) |
| `/api/{key}/series/81189/all/en.zip` | show/episode details, images | works: `en.xml` (62 episodes + 18 specials), `banners.xml`, `actors.xml` |
| `/api/GetSeriesByRemoteID.php?imdbid=tt0903747` | lookup by IMDB id | works (returns 81189) |
| `/api/{key}/languages.xml` | languages | works |

The empty search is the server's answer, not a client error: the same request for a
show that certainly exists returns valid, empty XML, while the by-ID calls for that
show succeed. Code path: `Addons/scraper.Data.TVDB/Scraper/clsScrapeTVDB.vb:130`
`SearchTVShowByName` → `External/TheTVDBApi/src/TVDB/Web/WebInterface.cs:345`
`GetSeriesByName` → zero `Series` → dialog shows no matches.

**Consequence.** TVDB can only scrape a show that already has a TVDB ID, from the NFO,
from another scraper (e.g. TMDB external IDs), or typed into the search dialog's TVDB ID
box. This likely explains why the owner's live setup works: TMDB runs first and may
supply the TVDB ID (not yet verified; TV test run 2/3 will show).

**Also seen (latent).** `SearchTVShowByName` returns `Nothing` when the client returns
`Nothing`, and both callers then read `r.Matches` (NullReferenceException). Today the
client only returns `Nothing` for empty arguments, so it is not reachable from this bug.

**Fix options (not decided).**
1. Fall back to TheTVDB **v4** `/search` for the name search only, keeping the working
   legacy by-ID calls. v4 needs a v4 API key (and may need a subscriber PIN); probe
   without a token returns 401.
2. Search by IMDB id first (`GetSeriesByRemoteID.php`, works) when the show has one,
   then by name.
3. Full migration of `External/TheTVDBApi` to v4 (largest; the by-ID endpoints still
   work today but may be retired too).

---

## BUG-013 — TVDB search dialog: OK stays enabled after a failed manual-ID Verify

- **Reported:** 2026-11-01 (owner, from earlier use of the installed 1.11.1)
- **Status:** open (low). Reported lookup failure is not a bug (see Retest); the OK-button
  defect below remains
- **Content type:** TV show
- **Scrapers enabled:** TMDB + TVDB (owner's install)

**Symptom.** In the TVDB search dialog, ticking "Manual TVDB Entry" and typing the show's
TVDB number did not get the show scraped.

**Findings so far (code reading, not reproduced).** The box is labelled correctly: it
takes a TVDB ID, and also accepts an IMDB ID starting with `tt`
(`Addons/scraper.Data.TVDB/Scraper/clsScrapeTVDB.vb:191-195`, `GetTVShowInfo`). A TVDB
ID goes straight to the full-series zip, which still works (BUG-012 probe table). So the
lookup itself should succeed today.

One candidate: `dlgTVDBSearchResults.SearchInfoDownloaded`
(`Addons/scraper.Data.TVDB/Scraper/dlgTVDBSearchResults.vb:244`) enables **OK** before
checking whether Verify returned anything. After a failed Verify the "Verification
Failed" box appears, but OK stays enabled. Pressing OK then returns an empty result, and
`GetSearchTVShowInfo` (`clsScrapeTVDB.vb:107`) silently scrapes nothing.

**To reproduce (dev build).** Scrape *Breaking Bad* → tick Manual TVDB Entry → `81189` →
Verify (details should appear) → OK. Repeat with `tt0903747`.

**Retest (2026-11-01, dev build).** Manual entry works with both `81189` and
`tt0903747`. The owner thinks the earlier failure was *Looney Tunes Golden Collection*,
looked up with a **TMDB** ID. A TMDB ID is also a plain number, so the box treats it as a
TVDB ID and fetches the wrong series, or nothing. Also, TMDB has this title only as six
**movies** (Vol. 1–6, e.g. id 465022). A TMDB TV search for it returns nothing (control:
the same movie search returns all six). So it can't be scraped as a TV show from TMDB at
all. Not an Ember defect. Remaining defect: the OK button after a failed Verify (above).
