# ################################################################################
# #                             EMBER MEDIA MANAGER                              #
# ################################################################################
# ################################################################################
# # This file is part of Ember Media Manager.                                    #
# #                                                                              #
# # Ember Media Manager is free software: you can redistribute it and/or modify  #
# # it under the terms of the GNU General Public License as published by         #
# # the Free Software Foundation, either version 3 of the License, or            #
# # (at your option) any later version.                                          #
# #                                                                              #
# # Ember Media Manager is distributed in the hope that it will be useful,       #
# # but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
# # GNU General Public License for more details.                                 #
# #                                                                              #
# # You should have received a copy of the GNU General Public License            #
# # along with Ember Media Manager.  If not, see <http://www.gnu.org/licenses/>. #
# ################################################################################

<#
.SYNOPSIS
    Creates the disposable L3 test library (docs/TEST_STANDARD.md section 8).

.DESCRIPTION
    Builds a tree of small dummy video files with realistic names under
    <repo>\testlib\ (git-ignored by the main repo), then makes that folder its
    own git repository with the starting state committed. After a test run:

        git -C testlib status      # what Ember created / changed / deleted
        git -C testlib diff        # exact NFO changes
        git -C testlib reset --hard; git -C testlib clean -fdx   # restore

    The files are dummies: MediaInfo/FFmpeg can't read them. Turn off the
    metadata scan and frame extraction in the test profile.

    No NFO files are generated. NFO fixtures must be captured from real
    Ember/Kodi output, not invented (TEST_STANDARD section 3).

.PARAMETER Path
    Target folder. Defaults to <repo>\testlib.

.PARAMETER Force
    Delete and recreate an existing test library. Only a folder that carries
    the marker file written by this script is ever deleted.
#>
[CmdletBinding()]
param(
    [string]$Path,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 leaves $PSScriptRoot empty inside param() defaults.
if (-not $Path) {
    $Path = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'testlib'
}
$MarkerName = '.ember-testlib'

# Each entry is a path relative to the library root. Grouped by the case it exercises.
$Files = @(
    # --- Movies: plain detection, several extensions
    'Movies\The Matrix (1999)\The Matrix (1999).mkv'
    'Movies\Heat (1995)\Heat (1995).avi'
    'Movies\Gattaca (1997)\Gattaca (1997).mp4'

    # --- Movies: one TMDB collection, three films (movie sets, BUG-004)
    'Movies\Back to the Future (1985)\Back to the Future (1985).mkv'
    'Movies\Back to the Future Part II (1989)\Back to the Future Part II (1989).avi'
    'Movies\Back to the Future Part III (1990)\Back to the Future Part III (1990).mp4'

    # --- Movies: stacked files (FileUtils.Common.isStacked)
    'Movies\Alien (1979)\Alien (1979) cd1.avi'
    'Movies\Alien (1979)\Alien (1979) cd2.avi'

    # --- Movies: DVD and Blu-ray folder structures
    'Movies\Casablanca (1942)\VIDEO_TS\VIDEO_TS.IFO'
    'Movies\Casablanca (1942)\VIDEO_TS\VTS_01_0.IFO'
    'Movies\Casablanca (1942)\VIDEO_TS\VTS_01_1.VOB'
    'Movies\Inception (2010)\BDMV\index.bdmv'
    'Movies\Inception (2010)\BDMV\STREAM\00000.m2ts'

    # --- Movies: title cleaning / filters (BUG-002) and punctuation
    'Movies\Blade Runner (1982)\Blade.Runner.1982.1080p.BluRay.x264.mkv'
    "Movies\Ocean's Eleven (2001)\Ocean's Eleven (2001).mkv"

    # --- TV: new show, two seasons + specials (BUG-001, season 0)
    'TV Shows\Breaking Bad (2008)\Season 1\Breaking.Bad.S01E01.mkv'
    'TV Shows\Breaking Bad (2008)\Season 1\Breaking.Bad.S01E02.mkv'
    'TV Shows\Breaking Bad (2008)\Season 1\Breaking.Bad.S01E03.mkv'
    'TV Shows\Breaking Bad (2008)\Season 2\Breaking.Bad.S02E01.mkv'
    'TV Shows\Breaking Bad (2008)\Season 2\Breaking.Bad.S02E02.mkv'
    'TV Shows\Breaking Bad (2008)\Season 0\Breaking.Bad.S00E01.mkv'

    # --- TV: second new show for single-episode scrapes, incl. a multi-episode file
    'TV Shows\The Expanse (2015)\Season 1\The.Expanse.S01E01.mkv'
    'TV Shows\The Expanse (2015)\Season 1\The.Expanse.S01E02.avi'
    'TV Shows\The Expanse (2015)\Season 1\The.Expanse.S01E03E04.mkv'

    # --- TV: date-based episodes (Scanner byDate path)
    'TV Shows\The Daily Show (1996)\Season 2021\The.Daily.Show.2021.03.01.mkv'
    'TV Shows\The Daily Show (1996)\Season 2021\The.Daily.Show.2021.03.02.mkv'
)

$fullPath = [IO.Path]::GetFullPath($Path)

if (Test-Path -LiteralPath $fullPath) {
    $marker = Join-Path $fullPath $MarkerName
    if (-not (Test-Path -LiteralPath $marker)) {
        throw "'$fullPath' exists and is not a test library created by this script (no $MarkerName). Refusing to touch it."
    }
    if (-not $Force) {
        throw "Test library already exists at '$fullPath'. Use -Force to recreate it, or restore it with: git -C `"$fullPath`" reset --hard; git -C `"$fullPath`" clean -fdx"
    }
    Remove-Item -LiteralPath $fullPath -Recurse -Force
}

New-Item -ItemType Directory -Path $fullPath | Out-Null
Set-Content -LiteralPath (Join-Path $fullPath $MarkerName) -Encoding ASCII -Value 'Created by tools/New-TestLibrary.ps1. Safe to delete.'

# 1 KB of zeros: non-empty, so no "empty file" special case is hit by accident.
$dummy = New-Object byte[] 1024
foreach ($relative in $Files) {
    $target = Join-Path $fullPath $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    [IO.File]::WriteAllBytes($target, $dummy)
}

# Byte-exact diffs: no line-ending conversion of the NFOs Ember writes.
Set-Content -LiteralPath (Join-Path $fullPath '.gitattributes') -Encoding ASCII -Value '* -text'

git -C $fullPath init --quiet
if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
git -C $fullPath add --all
git -C $fullPath -c user.name=testlib -c user.email=testlib@localhost -c commit.gpgsign=false commit --quiet -m 'initial test library'
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }

Write-Host "Test library created: $fullPath ($($Files.Count) video files)"
Write-Host "Movie source:   $(Join-Path $fullPath 'Movies')"
Write-Host "TV show source: $(Join-Path $fullPath 'TV Shows')"
