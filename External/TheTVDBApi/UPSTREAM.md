# Vendored: TheTVDBApi

C# wrapper for TheTVDB's **legacy XML API**, used by `Addons/scraper.Data.TVDB` and
`Addons/scraper.Image.TVDB` (project `TVDB`, GUID `{A265B83F-495E-43BD-B1F5-C89B58618A84}`).

| | |
|---|---|
| Source | https://github.com/DanCooper/TheTVDBApi |
| Commit | `62edeba6425cc71e219a848db8515c581c7e366f` (2019-11-29) |
| Licence | GPL v3 (`LICENSE`) — same as Ember Media Manager |
| Imported | 2026-10-31 |

## What was copied

`src/TVDB/`, `LICENSE`, `README.md` — unmodified.

Left out: `TheTVDBApi.sln`, `src/TVDBDocumentation/` (Sandcastle help project),
`test/TVDB.Test/` (NUnit tests against the legacy XML format), `.travis.yml`, icon.

## Notes

- Previously the main solution expected this as a sibling clone at `..\TheTVDBApi`.
  It is now referenced from `External\TheTVDBApi\src\TVDB\TVDB.csproj`.
- `TVDB.csproj` contains a `<None Include="..\..\..\..\OpenSourceHeader.licenseheader">`
  item pointing outside the repo. It only shows as a missing file in Visual Studio and
  does not affect the build.
- The upstream project is abandoned. TheTVDB has been retiring the legacy XML API in
  favour of API v4. Local changes are expected (e.g. a v4 migration); record them below.

## Local changes

- 2026-10-31 (`9297ff1b`): `TVDB.csproj` retargeted from .NET Framework 4.5 to 4.8.
  Current Visual Studio has no 4.5 targeting pack. All consumers already target 4.8.
  No source change.
