BeforeDiscovery {
  $projectPath = "$($PSScriptRoot)\..\.." | Convert-Path

  <#
    If the QA tests are run outside of the build script (e.g with Invoke-Pester)
    the parent scope has not set the variable $ProjectName.
  #>
  if (!$ProjectName) {
    # Assuming project folder name is project name.
    $ProjectName = Get-SamplerProjectName -BuildRoot $projectPath
  }

  $script:moduleName = $ProjectName

  Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue

  $mut = Get-Module -Name $script:moduleName -ListAvailable |
    Select-Object -First 1 |
    Import-Module -Force -ErrorAction Stop -PassThru | Where-Object -FilterScript { $_.Guid -ne (New-Guid -InputObject '00000000-0000-0000-0000-000000000000') }
}

Describe 'Create table and list object in memory db' -Tag 'DB' {

  BeforeAll {
    $query = 'CREATE TABLE "characters" (
                "id"        INTEGER,
                "name"      TEXT UNIQUE,
                "guild"     INTEGER,
                "TestNull"  TEXT NULL
            );'
    $c = New-SqliteConnection
  }
  # Careful
  # If you don't -keepAlive a memory connection, the db is dropped once the connection is closed
  It 'Should have a default connection string set to :memory:' -Skip:$skipTest {
    $c.ConnectionString | Should -Match ':memory:'
  }

  It 'Should be able to create a table' -Skip:$skipTest {
    # Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
    { Invoke-SqliteQuery -SqliteConnection $c -CommandText $query -keepAlive } | Should !-Throw
  }

  It 'Should have the created table in the list' {
    Invoke-SqliteQuery -SqliteConnection $c -CommandText 'SELECT name from sqlite_schema WHERE name = "characters"' -keepAlive
  }

  It 'Should have no row in the table' {
    $result = Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
    $result | Should -BeNullOrEmpty
  }

  It 'Should' {

    $result = Invoke-SqliteQuery -SqliteConnection $c -CommandText "INSERT INTO characters (id, name, guild) VALUES (1, 'John', 1);" -keepAlive
    $result | Should -BeNullOrEmpty

    $result = Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive
    $result | Should !-BeNullOrEmpty
    $result.Name | Should -Be 'John'
    # Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive -As PSCustomObject
    # Invoke-SqliteQuery -SqliteConnection $c -CommandText "SELECT * FROM characters;" -keepAlive -As OrderedDictionary
  }
}
