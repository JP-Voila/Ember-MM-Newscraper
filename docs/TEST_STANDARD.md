# Test Standard

What a test in this repo must **be**, and how a bug fix is tested. Adapted on 2026-10-31
from the owner's standard in another project, keeping the rules that apply to a VB.NET
WinForms app maintained by one person. [CLAUDE.md](../CLAUDE.md) holds the short rules;
this file holds the detail and the reasons.

Status: **no working test suite exists yet.** `EmberAPI_Test/` is stale and not in the
solution (see [INVENTORY.md](INVENTORY.md) §2). §2 describes the suite to build; until it
builds and runs, every claim of "tested" means manual testing, and must say so.

---

## 1. The four test layers

| Layer | What it proves | How it runs | Covers |
|---|---|---|---|
| **L1 Build** | The change compiles under `Option Strict On` | MSBuild `Debug\|x64` from the command line, after every change | Everything |
| **L2 Unit / characterization** | Logic behaves as asserted | MSTest project, `vstest.console.exe` | `EmberAPI` and addon logic that needs no UI and no network |
| **L3 Test library** | What Ember **writes to disk** (NFO, images, renames) | Dev build + test profile against a disposable git-tracked media folder | Scan → scrape → save, end to end |
| **L4 Manual** | What the user **sees**, and real-site behaviour | Per-bug test plan in [BUGS.md](BUGS.md) | UI, dialogs, live scrapers, the owner's real library |

A lower layer never stands in for a higher one when the property lives higher up. A
unit test of `NFO.SaveToNFO_Movie` does not prove the edit dialog saves the field. That
needs L3 or L4. Say which layer each claim rests on.

## 2. The unit suite (L2)

- **One test project**, MSTest, .NET Framework 4.8, legacy `packages.config` like the
  rest of the repo, added to `Ember Media Manager.sln`. It replaces `EmberAPI_Test`
  rather than reviving it.
- **What belongs in it.** Logic reachable without a form, a live HTTP call or the addon
  loader. Examples:
  - `NFO` merge and serialization
  - `MediaContainers` XML attributes (they *are* the NFO format)
  - `StringUtils` (title filters)
  - `Scanner` episode regexes
  - `FileUtils.GetFilenameList` naming
  - `Database` load/save against a temp SQLite file
  - pure helpers inside addons
- **What does not belong in it.** `frmMain`, dialogs, live scrapers. Those are L3/L4.
  Do not refactor production code just to make it unit-testable as part of a bug fix.
  If a seam is needed, that is its own change (CLAUDE.md "Working principles").
- **One primary subject per test file**, named after it
  (`NFO_MergeTVEpisodeTests.vb`). Split when a second subject appears, never by length.
- **Count properties, not cases.** Report "binds 3 properties, each bitten", not
  "+20 tests". A case that binds no property is deleted; cases differing only in a
  literal become one data-driven test (`<DataRow>`).

## 3. Fixtures describe states Ember can actually reach

- **Build objects the way production does.** Use the real constructors and setters, or
  `Database.Load_*` from a seeded temp DB. Never construct a `DBElement` in a shape no
  code path produces (e.g. an episode with a show ID but no show, or a `Season` of `-2`
  on `EpisodeDetails`).
- **Sentinels are part of the state.** `-1` = unset on episodes, `-2` on
  `SeasonDetails` (`-1` there means "* All Seasons"), season `0` = specials. A fixture
  uses the value the real code would hold (CLAUDE.md "Change checklists").
- **NFO and scraper-response fixtures are captured, not invented.** An NFO fixture is one
  Ember or Kodi actually wrote. A scraper response is a real saved response. Each fixture
  file records its source and capture date in a header comment or a sibling `.txt`. A
  hand-written "simplified" response proves only that the parser handles that one
  simplified shape.
- **No personal data in fixtures.** No real media paths from the owner's library, and no
  user-supplied credentials. Titles of real films/shows are fine.
- **Fixtures vary the shape, not just the content.** Include null, empty, a missing
  element, malformed XML, `-1`/`0`, and both NFO set forms (`<set>Name</set>` and
  `<set><name>…</name></set>`). A builder that only ever produces well-formed input
  can't catch a bug that only shows on bad input.
- **Avoid fixture-equals-default.** If a setting's default is `True`, a test that
  leaves it at `True` can't show the code reads the setting. Set the non-default value.

## 4. Global state, files, culture

- **`Master` is shared mutable state.** `Master.eSettings`, `Master.DB`,
  `Master.SettingsPath` and `Master.eLang` are `Shared`. A test that changes any of them:
  - saves the original value in `<TestInitialize>`;
  - restores it in `<TestCleanup>`;
  - never relies on what an earlier test left behind.

  Tests must pass in any order and when run alone.
- **Disk.** Each test that touches files uses its own temp folder and deletes it in
  cleanup. Never a path inside the repo, the install folder, or a media drive.
- **Database.** A test DB is a fresh temp `.emm` created from `DB/MyVideosDBSQL.txt`.
  Never the owner's `MyVideos48.emm`, or a copy of it committed to the repo.
- **Culture and dates.** Ember parses dates, numbers and ratings from text. A test that
  depends on parsing or formatting sets `CultureInfo` explicitly, and restores it, so
  it doesn't pass only on the owner's machine. Dates in fixtures are fixed literals,
  never `Date.Now`.
- **No network.** A unit test that makes an HTTP call is an L4 check in disguise. Feed
  it a saved response instead.

## 5. What an assertion may certify

- **A check must be able to fail.** A zero, empty or absent result counts only next to a
  positive control that proves the check can fire: the same search over input that
  *does* match, asserted non-zero. This applies to tests, greps and log reads alike.
  Example: "no `ERROR` in the log" means nothing for `TVDB_Data.Scraper_TVEpisode`,
  which logs `[Done]` whether or not it did anything.
- **Assert whole values, not presence.** Compare the full NFO element, the full
  episode/season numbers, the full list. Use `CollectionAssert.AreEqual` with an exact
  count rather than "contains". Checking that one item exists can't catch an extra or
  wrong item next to it.
- **Disk output is asserted at L3.** A unit test may check the XML Ember *generates*;
  only the test library proves which files landed where, and what else was changed or
  deleted (`forceFileCleanup` deletes files).
- **What the user sees is asserted at L4.** Dialog wording, which dialog opens, what
  Kodi displays: a unit test is not proof of any of these.

## 6. Bites: proving a test can fail

A test that has never been seen to fail is not evidence. Every **new bound property**
gets one bite:

1. **Green** — the test passes on the current code.
2. **Mutate** — make the smallest plausible wrong change to the *production code* that
   breaks the property, e.g.:
   - delete the guard;
   - flip the comparison;
   - read the wrong field;
   - return `Nothing`.

   State the property in one sentence. Deleting or weakening the assertion is never a
   valid mutation.
3. **Red for the right reason** — the target assertion fails with the expected message.
   A compile error, an exception in setup, or another test going red proves nothing.
4. **Revert exactly** the mutated lines; check with `git diff` that production code is
   back to clean.
5. **Green again**, then name the vacuity mode (below) most likely to apply and why it
   doesn't.

Record the bite briefly in the commit message (property, mutation, assertion that went
red). A record that lives only in a git-ignored file doesn't count.

Tests sharing exactly the same production guard *and* the same setup path may share one
bite. Any executable change to a test (fixture values, setup) needs a fresh bite.

### Vacuity modes to check against

- **green-with-fix-deleted** — the master check: remove the fix and the test still
  passes ⇒ not a test. When in doubt, run exactly this.
- **seeded-state-absent** — asserting something was cleared, skipped or protected when
  it was never there to begin with.
- **fixture-equals-default** — see §3.
- **identical-fixtures** — every input or scraper result is the same, so ordering or
  merge-priority bugs are invisible. Relevant to `MergeDataScraperResults_*`: give each
  scraper result different values.
- **harness-tests-its-own-stand-in** — the test replaces the very code it claims to
  test (a fake scraper standing in for the merge logic being tested).
- **leaked-static-state** — the property only holds because an earlier test left
  `Master.*` in a particular state (§4).
- **false-red twin** — a new check must first be shown to pass on clean, ordinary input
  (CRLF line endings, season 0, a title with an apostrophe) before it is shown to fail on
  bad input.

## 7. The bug lane: the failing test comes first

For a defect (not new behaviour):

1. **Reproduce it as a test** at the lowest layer that can show it. Use the real inputs
   from the report: assert the *correct* behaviour, which currently fails.
2. **Run it; confirm it fails for the expected reason** (§6 step 3).
3. **Commit the red test on its own**: `added: failing test for BUG-NNN …`. A test
   written after the fix can't tell "the bug is gone" from "the test was shaped around
   the new code".
4. **Fix the production code in a separate commit** (`fixed: BUG-NNN …`), **without
   touching the test file**. If the test has to change, the reproduction was wrong (go
   back to 1 and say so), or the fix changes the intended behaviour, which needs the
   owner's decision.
5. Update the bug's entry in BUGS.md: status, which layer proves the fix, and the L4
   steps the owner should run.

A diff that edits the test inside the fix commit is a red flag in review.

If the defect can only be shown at L3/L4 (UI flow, live site), write the L3/L4 steps
into BUGS.md **before** the fix, run them to see the failure, and say plainly in the
summary that no automated test covers it.

### Characterization tests (before changing existing behaviour)

When a change touches code with no tests, first write tests that **pin what it does
today**, bugs included, and get them green. Then the change should flip only the
assertions it means to change. Mark a pinned-but-wrong behaviour with its `BUG-NNN` in
the test name or comment, so a later fix knows which assertion is expected to flip.

## 8. The test library (L3)

A disposable media folder for anything that writes to disk:

- **Created by `tools/New-TestLibrary.ps1`** into `<repo>\testlib\`, which the main
  repo ignores (`.gitignore`). The script makes `testlib\` its **own git repo** with the
  starting state committed:
  ```
  powershell -ExecutionPolicy Bypass -File tools\New-TestLibrary.ps1          # create
  powershell -ExecutionPolicy Bypass -File tools\New-TestLibrary.ps1 -Force   # recreate
  ```
- **After a test run:**
  - `git -C testlib status` / `git -C testlib diff` show exactly which NFO/image files
    Ember created, changed or deleted;
  - `git -C testlib reset --hard; git -C testlib clean -fdx` restores it.
- **Safety.** The script only deletes a folder that carries its marker file
  `.ember-testlib`, so pointing `-Path` at real media fails. It does not wipe the
  folder. Verified 2026-11-01, along with: the nested repo detects created, modified
  and deleted files; restore works; the main repo ignores the folder.
- **Contents:** 26 dummy video files (1 KB of zeros) with realistic names, grouped by the
  case they exercise:
  - plain movies in `.mkv`/`.avi`/`.mp4`;
  - a 3-film collection (sets, BUG-004);
  - stacked `cd1`/`cd2` files;
  - `VIDEO_TS` and `BDMV` folders;
  - filter/punctuation titles (BUG-002);
  - a new show with seasons 1, 2 and 0 (BUG-001);
  - a second show with a multi-episode file;
  - date-based episodes.

  The list is in the script.
- **Dummy files have no streams.** MediaInfo/FFmpeg results are meaningless. Turn off the
  metadata scan and frame extraction in the test profile.
- **No NFOs are generated.** "Existing library" cases need captured NFOs (§3). Once Ember
  has scraped the test library, copy chosen NFOs into the script's fixtures, recording
  source and date.
- **The dev profile points only at this folder.** Disable the Trakt and Kodi interface
  addons in that profile (they would act on real accounts and hosts — INVENTORY §8).
- Scrapes at L3 use live sites. So a result that differs between runs may be the site
  changing, not Ember. Note the date of the run.

## 9. Manual test plans (L4)

Each bug in BUGS.md that is fixed gets a short numbered plan the owner can follow:
setup, steps, the expected result, and what to check on disk and in the log. A log check
includes its positive control (the line that *should* appear). The last step on the
owner's real library comes after copying the profile folder (`Profiles\<name>\`) as a
backup.
