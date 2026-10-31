# Bug log

Bugs ("niggles") found by the owner in the current executable, recorded as reported.
Each entry: symptom, steps, status, and findings once investigated. Session-level
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
