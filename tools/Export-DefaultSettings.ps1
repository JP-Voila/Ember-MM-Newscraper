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
    Writes the built EmberAPI's default Settings.xml, plus a flat "path = value"
    listing of it, so defaults can be read and diffed (docs/SETTINGS.md).

.DESCRIPTION
    Loads EmberAPI.dll from the build output, points Master.SettingsPath at an
    empty temp folder, runs Settings.Load() then Save(), and copies the result.
    Module on/off state and order are NOT in this file: ModulesManager writes
    them only when the app runs (Settings.xml <EmberModules>).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\Export-DefaultSettings.ps1 -OutDir docs\tmp\defaults
#>
[CmdletBinding()]
param(
    [string]$BuildDir,
    [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
if (-not $BuildDir) {
    $BuildDir = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'EmberMM - Debug - x64'
}
$OutDir = [IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$profileDir = Join-Path ([IO.Path]::GetTempPath()) ('ember-defaults-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $profileDir | Out-Null
try {
    [Environment]::CurrentDirectory = $BuildDir
    Add-Type -Path (Join-Path $BuildDir 'EmberAPI.dll')
    [EmberAPI.Master]::SettingsPath = $profileDir
    [EmberAPI.Master]::eSettings.Load()
    [EmberAPI.Master]::eSettings.Save()
    $xmlOut = Join-Path $OutDir 'Settings.default.xml'
    Copy-Item -LiteralPath (Join-Path $profileDir 'Settings.xml') -Destination $xmlOut -Force
}
finally {
    Remove-Item -LiteralPath $profileDir -Recurse -Force
}

# Flatten to one "path = value" line per leaf element; repeated siblings get [index].
$xml = New-Object Xml.XmlDocument
$xml.Load($xmlOut)
$lines = New-Object Collections.Generic.List[string]
function Add-Leaves($node, [string]$path) {
    $elements = @($node.ChildNodes | Where-Object { $_.NodeType -eq 'Element' })
    if ($elements.Count -eq 0) { $lines.Add("$path = $($node.InnerText)"); return }
    $index = 0
    foreach ($child in $elements) {
        $sameName = @($elements | Where-Object { $_.Name -eq $child.Name }).Count
        if ($sameName -gt 1) { Add-Leaves $child "$path/$($child.Name)[$index]"; $index++ }
        else { Add-Leaves $child "$path/$($child.Name)" }
    }
}
Add-Leaves $xml.DocumentElement ''
$flatOut = Join-Path $OutDir 'Settings.default.flat.txt'
[IO.File]::WriteAllLines($flatOut, $lines)

Write-Host "Defaults: $xmlOut"
Write-Host "Flat:     $flatOut ($($lines.Count) values)"
