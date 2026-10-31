# Security Policy

## Project status

This is a personal-use fork of Ember Media Manager, a Windows desktop application.
It is maintained on a best-effort basis for bug fixes; only the latest code on the
default branch is supported. There is no hosted service and no telemetry.

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Use GitHub's
"Report a vulnerability" (private security advisory) feature on this repository, or
contact the repository owner directly. Include affected files/versions, reproduction
steps, and impact. Expect a response on a best-effort basis.

## Threat model (what matters for this app)

Ember runs locally with the user's privileges, reads/writes files in the user's media
folders, and talks to third-party web services. The relevant risks are:

| Area | Risk | Where |
|---|---|---|
| Embedded API credentials | Keys in source can be extracted and abused / revoked by the provider | see below |
| Untrusted remote content | Scraped HTML/JSON/XML/images from third-party sites is attacker-influenceable if a site is compromised or via MITM | `EmberAPI/clsAPIHTTP.vb`, `Addons/scraper.*` |
| XML parsing | NFO files, `Settings.xml`, scraper responses — avoid enabling DTD processing / external entities | `clsAPINFO.vb`, `clsAPIXML.vb`, `clsAPISettings.vb` |
| File system writes | Filenames built from scraped titles must be sanitised to avoid path traversal or writing outside the media folder | `clsAPIFileUtils.vb`, `clsAPIImages.vb`, BulkRename addon |
| SQL | All DB access should use parameterised `SQLiteCommand`s, never string-concatenated values from scraped data or filenames | `clsAPIDatabase.vb` |
| Plug-in loading | Every `*.dll` under the `Modules` folder is loaded and executed via `Assembly.LoadFile`. Anyone who can write there can run code as the user | `clsAPIModules.vb` |
| External processes | FFmpeg/MediaInfo and shell context-menu integration run external commands with file paths | `clsAPIFFmpeg.vb`, `clsAPIMediaInfo.vb`, `ContextMenuAdd.reg` |
| Downloads | Trailer/theme downloads (YouTube etc.) write remote content to disk | `clsAPIYouTube.vb`, `Addons/scraper.Trailer.*`, `Addons/scraper.Theme.*` |
| Kodi / Trakt credentials | Kodi host passwords and Trakt tokens are stored in the user's settings files in plain text | `Addons/generic.Interface.*` |

## Known issues in the repository

These are inherited from upstream and are documented here so they are not made worse:

1. **Hardcoded third-party API keys** are compiled into the application:
   - TMDB: `Addons/scraper.TMDB.Data/TMDB_Data.vb`, `Addons/scraper.TMDB.Poster/TMDB_Image.vb`,
     `Addons/scraper.TMDB.Trailer/TMDB_trailer.vb` (`_strAPIKey`)
   - Trakt.tv: `Trakttv/TraktSettings.cs` (`_apiKey`)
   - Other scrapers (e.g. Fanart.tv, TVDB, OMDb) may have defaults in their settings code.

   These are application/client keys from the original project, are already public in git
   history, and may be revoked by the providers at any time. Most scrapers let the user
   supply a personal key in settings — prefer that. Do not add new hardcoded keys; if a
   key must change, prefer making it user-configurable.
2. **`EmberMediaManager/Ember Media Manager_TemporaryKey.pfx`** is a Visual Studio
   ClickOnce temporary signing key committed by upstream. It has no trust value; do not use
   it to sign anything you distribute.
3. **Third-party binaries are committed** (`.nuget/NuGet.exe`, `BuildSetup/*.exe`,
   `BuildSetup/pcre.dll`, native SQLite interop DLLs under `EmberAPI/x86|x64`). Their
   provenance is upstream; replace from official sources if in doubt.
4. **Dependencies are dated** (packages last updated ~2022). Check advisories before
   relying on any package for parsing untrusted input.

## Guidance for contributors and AI agents

- Never commit secrets, tokens, personal `Settings.xml`, databases (`*.emm`), logs, or
  paths that reveal personal media libraries.
- Never print or log API keys, tokens or passwords (including in NLog output).
- Use parameterised SQL. Sanitise any scraped string before using it in a file path.
- Treat everything returned by a scraper as untrusted input.
- Don't widen the plug-in loading mechanism (e.g. loading DLLs from new locations or URLs).
- Flag, rather than silently fix, any security issue found while working on something
  else, so it can be handled as its own change.
