
$script:moduleRoot = Convert-Path "$PSScriptRoot\.."
Remove-Module -Name 'clihelper.sqlite' -Force -ErrorAction SilentlyContinue -Verbose:$false
$script:mut = Import-Module "$script:moduleRoot\clihelper.sqlite.psd1" -Force -PassThru -ErrorAction Stop -Verbose:$false

Write-Host '[=] Can run Inmemory CRUD Operations' -f Green
try {
  $config = [SQLiteDBConfig]::new('Data Source=:memory:;Cache=Shared;')
  $res = @{
    0 = [PsCustomObject]@{
      t = "Failed"
      c = "Red"
    }
    1 = [PsCustomObject]@{
      t = "Passed"
      c = "Green"
    }
  }
  $colId = [SqliteColumn]::new()
  $colId.Name = 'id'
  $colId.Type = [SqliteType]::INTEGER
  $colId.PrimaryKey = $true
  $colId.AllowNull = $false

  $colName = [SqliteColumn]::new()
  $colName.Name = 'name'
  $colName.Type = [SqliteType]::TEXT
  $colName.AllowNull = $false
  $colName.Unique = $true

  $colGuild = [SqliteColumn]::new()
  $colGuild.Name = 'guild'
  $colGuild.Type = [SqliteType]::INTEGER

  $colNull = [SqliteColumn]::new()
  $colNull.Name = 'TestNull'
  $colNull.Type = [SqliteType]::TEXT

  $table = [SqliteTable]::new()
  $table.Name = 'characters'
  $table.ifNotExists = $true
  $table.Columns = @($colId, $colName, $colGuild, $colNull)

  $schema = [SqliteDBSchema]::new()
  $schema.Tables = @($table)
  $config.Schema = $schema
  $config.Version = '1'

  $c = [SqliteHelper]::NewConnection($config.ConnectionString)
  Write-Host '[+] Runs DatabaseSDL with no errors ' -NoNewline
  [void][SqliteHelper]::InvokeSqliteQuery($c, $config.GetDatabaseSDL())
  Write-Host $res[[int]$?].t -f $res[[int]$?].c


  Write-Host '[+] NewRow Should insert a row and return the new record ' -NoNewline
  $NewRow_result = [SqliteHelper]::NewRow($config, 'characters', @{ name = 'John'; guild = 1 }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c
  if (!([string]$NewRow_result.name -eq 'John' -and [string]$NewRow_result.guild -eq "1")) {
    # add to the errorlists
  }
  Write-Host '[+] NewRow Should insert a second row ' -NoNewline
  $NewRow_result = [SqliteHelper]::NewRow($config, 'characters', @{ name = 'Jane'; guild = 2 }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c
  if ($NewRow_result) {
    $NewRow_result.name | Should -Be 'Jane'
  }

  Write-Host '[+] GetRow Should retrieve rows by clause ' -NoNewline
  $GetRow_result = [SqliteHelper]::GetRow($config, 'characters', @{ name = 'John' }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c
  if ([string]$GetRow_result.name -ne 'John') {
    # add to the errorlists
  }

  Write-Host '[+] GetRow Should support LIKE with wildcard ' -NoNewline
  $GetRow_result = [SqliteHelper]::GetRow($config, 'characters', @{ name = 'Joh*' }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c
  if ([string]$GetRow_result.name -ne 'John') {
    # add to the errorlists
  }

  Write-Host '[+] GetRow Should return empty for no match ' -NoNewline
  $GetRow_result = [SqliteHelper]::GetRow($config, 'characters', @{ name = 'Nobody' }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c

  Write-Host '[+] SetRow Should update a row by clause ' -NoNewline
  [void][SqliteHelper]::SetRow($config, 'characters', @{ guild = 99 }, @{ name = 'John' }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c
  Write-Host '[+] SetRow Should verify the updated value' -NoNewline
  $SetRow_result = [SqliteHelper]::GetRow($config, 'characters', @{ name = 'John' }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c
  if ([int]$SetRow_result.guild -ne 99) {
    # add to the errorlist
  }


  Write-Host '[+] RemoveRow Should delete a row by clause ' -NoNewline
  [SqliteHelper]::RemoveRow($config, 'characters', @{ name = 'Jane' }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c
  Write-Host '[+] RemoveRow Should verify the row is gone ' -NoNewline
  $RemoveRow_result = [SqliteHelper]::GetRow($config, 'characters', @{ name = 'Jane' }, [Microsoft.Data.Sqlite.SqliteConnection]$c)
  Write-Host $res[[int]$?].t -f $res[[int]$?].c
  if ($null -ne $RemoveRow_result) {
    # add to the errorlist
  }
} catch {
  Write-Host $_.Exception.Message -f Red
  Write-Host ($_.ScriptStackTrace | Out-String)
} finally {
  [SqliteHelper]::CloseConnection([Microsoft.Data.Sqlite.SqliteConnection]$c)
}

Write-Host '[=] Can run Inmemory SqliteQueries' -f Green
try {
  $query = 'CREATE TABLE "characters" (
    "id"    INTEGER,
    "name"    TEXT UNIQUE,
    "guild"    INTEGER,
    "TestNull"    TEXT NULL
  );'
  $conn = [SqliteHelper]::NewConnection('Data Source=:memory:;Cache=Shared;')
  # [SqliteHelper]::InvokeSqliteQuery($conn, "SELECT * FROM characters;", @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($conn, $query, @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($conn, "SELECT * FROM characters;", @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($conn, "INSERT INTO characters (id, name, guild) VALUES (1, 'John', 1);", @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($conn, "SELECT * FROM characters;", @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($conn, "SELECT * FROM characters;", @{}, 'PSCustomObject')
  [SqliteHelper]::InvokeSqliteQuery($conn, "SELECT * FROM characters;", @{}, 'OrderedDictionary')
} catch {
  Write-Host $_.Exception.Message -f Red
  Write-Host ($_.ScriptStackTrace | Out-String)
} finally {
  [SqliteHelper]::CloseConnection($conn)
  [SqliteHelper]::CloseConnection($c)
}

try {
  Write-Host '[+] Can run file SqliteQuery'
  $dataSource = Join-Path -Path (Get-Location).Path -ChildPath 'test.sqlite'
  if (!(Test-Path -Path $dataSource)) { $null = New-Item -Path $dataSource -ItemType File -Force }
  $fsqlitecon = [SqliteHelper]::NewConnection(('Data Source={0};' -f $dataSource))
  # [SqliteHelper]::InvokeSqliteQuery($fsqlitecon, "SELECT * FROM characters;", @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($fsqlitecon, $query, @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($fsqlitecon, "SELECT * FROM characters;", @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($fsqlitecon, "INSERT INTO characters (id, name, guild) VALUES (1, 'John', 1);", @{}, 'DataTable')
  [SqliteHelper]::InvokeSqliteQuery($fsqlitecon, "SELECT * FROM characters;", @{}, 'DataTable')
  # [SqliteHelper]::InvokeSqliteQuery($fsqlitecon, "DELETE FROM characters WHERE id = 1;", @{}, 'DataTable')
} catch {
  Write-Host $_.Exception.Message -f Red
  Write-Host ($_.ScriptStackTrace | Out-String)
} finally {
  Write-Host '[+] Connection Should close a specific connection without error'
  { [SqliteHelper]::CloseConnection($fsqlitecon) } | Should -Not -Throw
  del $pwd\test.sqlite -ea Ignore
}