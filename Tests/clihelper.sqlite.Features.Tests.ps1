BeforeDiscovery {
  $script:moduleRoot = Convert-Path "$PSScriptRoot\.."
  Remove-Module -Name 'clihelper.sqlite' -Force -ErrorAction SilentlyContinue
  $script:mut = Import-Module "$script:moduleRoot\clihelper.sqlite.psd1" -Force -PassThru -ErrorAction Stop
}

Describe 'SqliteHelper static methods' -Tag 'DB' {
  BeforeAll {
    $script:query = 'CREATE TABLE "characters" (
                "id"        INTEGER,
                "name"      TEXT UNIQUE,
                "guild"     INTEGER,
                "TestNull"  TEXT NULL
            );'
    $script:c = [SqliteHelper]::NewConnection('Data Source=:memory:;Cache=Shared;')
  }

  AfterAll {
    [SqliteHelper]::CloseConnection($script:c)
  }

  It 'Should have a connection string set to :memory:' {
    $script:c.ConnectionString | Should -Match ':memory:'
  }

  It 'Should be able to create a table' {
    { [SqliteHelper]::InvokeSqliteQuery($script:c, $script:query) } | Should -Not -Throw
  }

  It 'Should have the created table in the schema' {
    $result = [SqliteHelper]::InvokeSqliteQuery($script:c, 'SELECT name from sqlite_schema WHERE name = "characters"', @{}, 'PSCustomObject')
    $result | Should -Not -BeNullOrEmpty
  }

  It 'Should have no rows in the table' {
    $result = [SqliteHelper]::InvokeSqliteQuery($script:c, 'SELECT * FROM characters;', @{}, 'PSCustomObject')
    $result | Should -BeNullOrEmpty
  }

  It 'Should insert a row and return affected row count' {
    $result = [SqliteHelper]::InvokeSqliteQuery($script:c, "INSERT INTO characters (id, name, guild) VALUES (1, 'John', 1);", @{}, 'NonQuery')
    $result | Should -Be 1
  }

  It 'Should retrieve the inserted row' {
    $result = [SqliteHelper]::InvokeSqliteQuery($script:c, 'SELECT * FROM characters;', @{}, 'PSCustomObject')
    $result | Should -Not -BeNullOrEmpty
    $result.Name | Should -Be 'John'
  }

  It 'Should return results as DataTable when specified' {
    $result = [SqliteHelper]::InvokeSqliteQuery($script:c, 'SELECT * FROM characters;')
    $result -is [System.Data.DataTable] | Should -BeTrue
    $result.Rows.Count | Should -Be 1
  }
}
