# Worklog

Running record of work in progress, findings and open questions, so a new agent session
can pick up where the last one stopped. Stable rules live in [CLAUDE.md](../CLAUDE.md);
this file is for state that changes.

**Agents:** read this at the start of a session. Before ending a session, update
"Current status" and "Open items", and add a dated entry under "Session history".
Keep entries short and factual; move anything that becomes a permanent rule into
CLAUDE.md.

---

## Current status (2026-10-31)

- Branch: `claude/great-mayer-c5646v` (not yet merged to `master`; no PR opened).
- Done: agent context files, vendored TheTVDBApi into `External/`.
- **In progress:** owner is testing whether TheTVDB's legacy XML API still works
  (see "TVDB investigation" below).
- Bugs are being logged in [BUGS.md](BUGS.md): BUG-001 (single-episode scrape of an
  unscraped show) has its root cause found, fix option not chosen yet. BUG-002 (regex
  filter), BUG-003 (trailers) and BUG-004 (Kodi sets) are open.
- Development is now in a **local Windows** Claude Code session (`D:\Ember-MM-Newscraper`).
- **Build: green.** All 31 solution projects build from the command line
  (Debug|x64 clean rebuild, 0 errors, 2026-11-01), after the old TagManager addon was
  removed from the solution (BUG-005). The dev build has **not been launched** yet.
- **Test library ready:** `tools/New-TestLibrary.ps1` → `testlib/` (git-ignored, own
  nested repo). Dev build launched (after the BUG-010 fix), sources added, Update Library
  ran, "Scan Meta Data" off for Movies and TV.
- **TV isolation run 1 (TVDB only) done, 2026-11-01:** TVDB name search is dead
  upstream (BUG-012); by-ID calls still work. BUG-001 confirmed with TVDB alone (silent
  cancel). **Next:** run 2, TMDB only; then run 3, both. Then L2 test project.
- **TV run 2 (TMDB only)** exposed BUG-017 (an upstream commit inverted the scrape-result
  checks; every dev-build scrape outcome was wrong). Fixed. Run 1 and BUG-001's dev-build
  notes predate the fix.
- **Run 2 repeated on the fixed build (2026-11-01 22:45):**
  - *The Expanse* S01E01 alone: TMDB aborts (no show TMDB ID), and Ember cancels with no
    message (BUG-001, now the intended path).
  - *Breaking Bad* whole show: data → images → save. `tvshow.nfo` has tvdb 81189
    (default), imdb tt0903747 and tmdb 1396. Episode NFOs have titles, aired dates,
    plots and all three IDs. Actor thumbs were saved.
  - This confirms that **TMDB supplies the TVDB ID**, which is why the live TMDB+TVDB
    setup works despite BUG-012.
  - No show artwork at first: BUG-017 part 2 (37 more inverted image/theme/trailer checks), fixed. After it: poster, fanart, banner, extrafanart, season art and episode thumbs are written with Frodo names.
  - BUG-018 was logged from the stale pre-fix Expanse NFO.
- **TV run 3 (TMDB first, then TVDB), 2026-11-01 23:04: pass.** *The Expanse* whole show:
  the chain ran TMDB → TVDB → images → save. `tvshow.nfo` has tvdb 280619 (default),
  imdb tt3230854 and tmdb 63639. The `S01E03E04.nfo` double episode holds two
  `<episodedetails>` (E03 *Remember the Cant*, E04 *CQB*) with the right dates. The
  stale BUG-018 NFO was overwritten with correct data. Isolation runs are done.
- **L2 suite added (2026-11-01):** `EmberAPI.Tests/` (MSTest 2.2.10, `packages.config`, in
  the solution, own `bin\` output). It has 2 `Settings.Load` tests, each bitten (see the
  commit). **Next:** bug lane for BUG-015 / -016 / -011 / -018, red test first.
- Owner's roadmap (2026-11-01): get everything working → polish/improve → deploy. The
  live install is "good enough" meanwhile, so there is no rush.
- Image picker, owner question: is OK safe while the "loading images" indicators show?
  Yes. OK runs `dlgImgSelect.DoneAndClose`, which disables OK, cancels and **waits for**
  both background workers, then downloads the chosen images at full size on the UI thread
  ("Downloading Fullsize Image(s)..." appears only at that point). The background
  workers only load preview thumbnails. Episode/season images are downloaded during the
  DB save.
- Live-install issues the owner reported on 2026-11-01 are logged as BUG-013 (TVDB manual
  entry: only the OK-after-failed-Verify defect remains), BUG-014 (TMDB Cancel blocks
  TVDB; workaround verified), BUG-015 (VACUUM crash after the library clean) and
  BUG-016 ("Part 1" not stacked). The owner's own items are sorted with workarounds.

## Open items

- [ ] TVDB legacy API: name search dead, by-ID calls work (BUG-012, 2026-11-01). Decide
      fix: v4 search only, IMDB-id lookup first, or full v4 migration. v4 needs a key
      (free under $50k/yr revenue, attribution required). The owner is undecided about
      signing up; option 2 (IMDB id first) needs no key.
- [ ] Owner's bug list — being recorded in [BUGS.md](BUGS.md) as reported.
- [x] Set up testing per TEST_STANDARD: L1 command-line build, L2 `EmberAPI.Tests`
      (2026-11-01, 2 tests), L3 test library + generator script.
- [ ] Tag Manager must work (owner, 2026-10-31). Approach chosen: in-app Tag Manager.
      BUG-005 fixed (old addon out of the solution); BUG-006 to fix via the bug lane.
- [ ] L3 first launch on `testlib/` (owner), then capture real NFOs as fixtures.
- [ ] NuGet advisory: Newtonsoft.Json 12.0.3 in the two Trakt projects (NU1903). Decide
      whether to align them on 13.0.1 as a separate change.
- [x] Exact build command recorded in CLAUDE.md (2026-10-31).
- [ ] Version numbers disagree: assemblies say `1.11.1.0`
      (`EmberMediaManager/My Project/AssemblyInfo.vb`), installer scripts say `1.12.0`
      (`BuildSetup/0_BuildSetup_x64.bat`), `Changelog.txt` stops at `1.4.7.2` (2015).
      Decide on a version scheme before shipping a build. Low priority.
- [ ] Dead projects on disk, not in the solution: `Addons/scraper.EmberCore.XML`,
      `Addons/scraper.TVDB.Poster`, `Trakttv/` (see INVENTORY §2). Decide whether to
      delete. Low priority.
- [ ] `EmberAPI_Test/` (stale, not in the solution) is superseded by `EmberAPI.Tests/`.
      Decide whether to delete it. Low priority.

---

## TVDB investigation

### Background

- `scraper.Data.TVDB` and `scraper.Image.TVDB` use `External/TheTVDBApi`
  (DanCooper/TheTVDBApi @ `62edeba`, 2019), which calls TheTVDB's **legacy XML API**:
  `http://thetvdb.com/api/{key}/series/{id}/all/{lang}.zip` (and `mirrors.xml`).
- TheTVDB announced retirement of legacy APIs (v1–v3) in favour of v4 around 2021–2022;
  whether the endpoint is still live was **not confirmed** (the cloud container's network
  could not reach thetvdb.com).
- Note: `https://github.com/dbr/tvdb_api` is an unrelated **Python** library — not the
  dependency.

### How to read the logs (verified in code)

Log file: `<install dir>\Log\<yyyy-MM-dd>.csv` (all levels from Trace).

- `ScrapeData_TVSeason … [Using] TVDB_Data … [No Scraper Results]` is **expected**:
  `TVDB_Data.Scraper_TVSeason` is a stub that always returns `Nothing`
  (`Addons/scraper.Data.TVDB/TVDB_Data.vb:335`). Not a failure.
- `[TVDB_Image] [Scraper] [Start]` → `[Done]` is logged whether or not images were found.
  A failed download/unzip throws and is logged as an **`ERROR`** line by
  `clsScrapeTVDB.GetImages_TV` (`Addons/scraper.Image.TVDB/Scraper/clsScrapeTVDB.vb:207`).
  No ERROR between Start and Done ⇒ probably succeeded.
- `TVDB_Data.Scraper_TVEpisode` **silently skips** (still logs `[Done]`, returns an empty
  container) when the show has no TVDB ID (`Addons/scraper.Data.TVDB/TVDB_Data.vb:320`).
  If TMDB scraped the show and didn't supply a TVDB ID, TVDB episode scraping does nothing.
- Data scrapers run in order and only fill **empty** fields; if TMDB runs first it can
  mask whether TVDB contributed anything.

### Proof-of-download file

The library writes every series download to
`<install dir>\Temp\Shows\loaded.zip` (overwritten each time, never deleted). It should
contain `en.xml`, `banners.xml`, `actors.xml`. It holds only the **last** show fetched,
and the image scraper fetches twice per show (content language, then `en`).

### Owner's setup (as reported)

TV scrapers enabled: TMDB, and TVDB for episode data. A first check of `loaded.zip`
did not show the show that had been scraped (Accel World) — inconclusive, because the
file only holds the last download.

### Test plan (owner running this)

1. Pick a show that has never been scraped.
2. For the test, make TVDB the only (or first) episode data scraper.
3. After scraping, confirm the show has a TVDB ID (edit dialog).
4. Check: log has `[TVDB_Data] [Scraper_TVEpisode]` / `[TVDB_Image] [Scraper]` lines and
   no `ERROR` between them; `Temp\Shows\loaded.zip` timestamp matches and `en.xml` names
   the new show; episode plot/aired/title are filled.

### Result (2026-11-01)

Mixed: `GetSeries.php` (name search) returns empty `<Data></Data>` for every query;
series XML, `all/en.zip`, `GetSeriesByRemoteID.php` and `languages.xml` all work.
Details and probe table in BUGS.md BUG-012.

### Decision

- All checks pass → legacy API still works; v4 migration is optional, not urgent.
- ERROR lines, stale/empty zip, or HTML/error text in the zip → legacy API is dead;
  plan a v4 migration of `External/TheTVDBApi` (needs a v4 API key; TheTVDB's licence
  terms changed in 2021 and may require a subscriber PIN). Record local changes in
  `External/TheTVDBApi/UPSTREAM.md`.

---

## Development environment

- **Cloud sessions** (claude.ai/code): no .NET compiler, can't run the app, outbound
  access to scraper sites may be blocked. Fine for reading code and planning; every
  change must be built and tested by the owner on Windows.
- **Local (preferred):** owner's Windows machine with Visual Studio. Claude Code installed
  via PowerShell (`irm https://claude.ai/install.ps1 | iex`, then reopen the terminal).
  Running from a "Developer PowerShell for VS" prompt puts MSBuild on PATH.
- Keep the clone separate from the owner's installed copy of Ember. Build output goes to
  `<repo>\EmberMM - <Config> - <Platform>\` (inside the repo, git-ignored). The clone at
  `D:\Ember-MM-Newscraper` is fine.
- The old sibling `..\TheTVDBApi` clone is no longer used.

---

## Session history

### 2026-10-31 — local session: bug log + agent rules

- Created `docs/BUGS.md` and logged BUG-001…004. BUG-001's root cause (episode scrapers
  need show IDs; nothing searches for the show first) was found from an owner log.
- `docs/tmp/` added to `.gitignore` as scratch for owner logs and imported files.
- Merged the rules that apply here from another project's CLAUDE.md/SECURITY.md (kept in
  `docs/tmp/`, not committed):
  - CLAUDE.md: working principles, change checklists, bug workflow.
  - SECURITY.md: zip extraction, XML DTD rule, pre-merge checklist.
- Wrote `docs/INVENTORY.md`: projects (incl. 4 dead ones on disk), addon→interface map,
  EmberAPI/app responsibilities, startup/scan/scrape/save flows, persisted state, and
  change seams ranked by blast radius and reversibility.
- Wrote `docs/TEST_STANDARD.md`, adapted from the owner's other project:
  - four test layers;
  - fixture, global-state and culture rules;
  - the bite protocol and vacuity modes;
  - the bug lane (red test committed first);
  - the git-tracked test library.

  Dropped: frontend/React, money arithmetic, clock-drift, fences, review-round
  calibration, the execution ledger.
- Build environment: VS Build Tools 2026 (MSBuild 18, vbc, vstest.console). The owner
  installed the .NET Framework 4.8 targeting pack.
- **First build (Debug|x64).** Upstream HEAD did **not** compile: its last commits
  (2242d240, c7235061, Nov/Dec 2022) were an unfinished cleanup.
  - `3da4d639` restored the removed import/enum and fixed two half-renames.
  - `9297ff1b` retargeted TVDB + KodiAPI to 4.8.
  - Result: 31 of 32 projects build, including `EmberAPI` and the exe.
  - Still failing: `generic.EmberCore.TagManager`. It calls `Database.Save_Tag_Movie` /
    `Delete_Tag`, which upstream removed in d08f4dae when it built a replacement Tag
    Manager into the app (Tools → Tag Manager, `EmberMediaManager/dlgTagManager.vb`).
    Owner decision pending.
- Build output is **inside** the repo (`<repo>\EmberMM - Debug - x64\`, git-ignored),
  not a sibling folder as the docs had said; docs corrected.
- NuGet restore warns NU1903: `Newtonsoft.Json` 12.0.3 (high, GHSA-5crp-9r3c-p9vr) in
  `generic.Interface.Trakttv` and `scraper.Data.Trakttv`. Not changed (no package
  upgrades as a side effect); listed in open items.
- Implication: the owner's installed exe was built from an earlier commit than HEAD. Its
  behaviour may differ from this code (e.g. which Tag Manager exists).
- 2026-11-01: removed old TagManager addon from the solution (BUG-005). The full
  solution is green. Warning baseline: 204, all pre-existing. Kinds: MSB3277 package
  version conflicts, CS0472 in the C# libs, BC40008 obsolete APIs, a few others. Added
  `tools/New-TestLibrary.ps1` and verified its guards and the nested-repo diff.
- 2026-11-01: the owner's first launch of the dev build crashed: BUG-010, missing
  `Settings.xml` on a new profile, an upstream 2022 regression. Fixed; reproduced red
  before the fix with a script against `EmberAPI.dll`, since there is no test project
  yet. Logged BUG-011, found alongside: Settings.xml repair can't work.
- 2026-11-01: wrote `docs/SETTINGS.md` (dev-build defaults, generated by
  `tools/Export-DefaultSettings.ps1` plus the dev profile's `<EmberModules>`). Key
  findings:
  - TV data is TVDB-only by default; TMDB is **off** for TV, but **on** in the owner's
    install, per the owner's log.
  - Metadata scan is on by default.
  - Movie NFO `<set>` uses the plain form (`CollectionsExtendedInfo` false).
- 2026-11-01: TV isolation run 1 (TVDB only). Episode scrape of an unscraped show
  cancels silently (BUG-001). Show scrape: "No matches found". Probing the legacy API
  directly showed name search returns empty XML for every query while by-ID and
  IMDB-id lookups work: logged BUG-012.
- `clsAPIHTTP.vb` logs full request URLs on error. The owner ruled API-key leakage a
  non-issue (the built-in keys are already public), so it is not tracked. Only
  end-user-supplied credentials (Kodi password, Trakt token, personal API keys entered
  in Settings) must stay out of logs. Anything already public in the source is out of
  scope.

### 2026-10-31 — cloud session: onboarding + TVDB dependency

- Added `CLAUDE.md`, `SECURITY.md`, `AGENTS.md`, `.editorconfig`.
- Findings recorded in CLAUDE.md/SECURITY.md: Windows-only build, hardcoded TMDB/Trakt
  API keys, committed temporary `.pfx`, bundled binaries, stale test project.
- Identified the missing solution dependency as DanCooper/TheTVDBApi (matching project
  GUID `{A265B83F-495E-43BD-B1F5-C89B58618A84}`); vendored it into
  `External/TheTVDBApi/` and repointed the `.sln` and both TVDB `.vbproj` files.
  **Not yet build-verified on Windows.**
- Analysed an owner-supplied log excerpt (see "How to read the logs"); set up the TVDB
  test plan above.
