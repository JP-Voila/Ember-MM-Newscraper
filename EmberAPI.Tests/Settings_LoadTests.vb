' ################################################################################
' #                             EMBER MEDIA MANAGER                              #
' ################################################################################
' ################################################################################
' # This file is part of Ember Media Manager.                                    #
' #                                                                              #
' # Ember Media Manager is free software: you can redistribute it and/or modify  #
' # it under the terms of the GNU General Public License as published by         #
' # the Free Software Foundation, either version 3 of the License, or            #
' # (at your option) any later version.                                          #
' #                                                                              #
' # Ember Media Manager is distributed in the hope that it will be useful,       #
' # but WITHOUT ANY WARRANTY; without even the implied warranty of               #
' # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
' # GNU General Public License for more details.                                 #
' #                                                                              #
' # You should have received a copy of the GNU General Public License            #
' # along with Ember Media Manager.  If not, see <http://www.gnu.org/licenses/>. #
' ################################################################################

Imports EmberAPI

<TestClass>
Public Class Settings_LoadTests

    Private _origSettingsPath As String
    Private _origSettings As Settings
    Private _profileDir As String

    <TestInitialize>
    Public Sub Init()
        _origSettingsPath = Master.SettingsPath
        _origSettings = Master.eSettings
        _profileDir = Path.Combine(Path.GetTempPath(), "ember-test-" & Guid.NewGuid().ToString("N"))
        Directory.CreateDirectory(_profileDir)
        Master.SettingsPath = _profileDir
        Master.eSettings = New Settings
    End Sub

    <TestCleanup>
    Public Sub Cleanup()
        Master.SettingsPath = _origSettingsPath
        Master.eSettings = _origSettings
        If Directory.Exists(_profileDir) Then Directory.Delete(_profileDir, True)
    End Sub

    'BUG-010: a new profile has no Settings.xml; Load must fall back to defaults instead of throwing
    <TestMethod>
    Public Sub Load_ProfileWithoutSettingsXml_DoesNotThrow()
        Assert.IsFalse(File.Exists(Path.Combine(_profileDir, "Settings.xml")), "precondition: profile has no Settings.xml")

        Try
            Master.eSettings.Load()
        Catch ex As Exception
            Assert.Fail("Load threw on a profile without Settings.xml: " & ex.GetType().Name & ": " & ex.Message)
        End Try

        Assert.IsTrue(Master.eSettings.MovieScraperCollectionsAuto, "a missing Settings.xml must leave the default (True)")
    End Sub

    'Positive control for the test above: with a Settings.xml present, Load reads it (non-default value round-trips)
    <TestMethod>
    Public Sub Load_ProfileWithSettingsXml_ReadsStoredValue()
        Master.eSettings.MovieScraperCollectionsAuto = False
        Master.eSettings.Save()
        Assert.IsTrue(File.Exists(Path.Combine(_profileDir, "Settings.xml")), "precondition: Save wrote Settings.xml")
        Master.eSettings = New Settings

        Master.eSettings.Load()

        Assert.IsFalse(Master.eSettings.MovieScraperCollectionsAuto, "Load must read the stored non-default value (False)")
    End Sub

End Class
