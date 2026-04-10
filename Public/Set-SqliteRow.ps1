function Set-SqliteRow {
  [CmdletBinding()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $true)]
    [SQLiteDBConfig]
    $SqliteDBConfig,

    [Parameter(Mandatory = $true)]
    [string]
    $TableName,

    [Parameter(Mandatory = $true)]
    [System.Collections.IDictionary]
    $RowData,

    [Parameter()]
    [System.Collections.IDictionary]
    $ClauseData = @{},

    [Parameter()]
    [switch]
    $CaseSensitive,

    [Parameter()]
    [Microsoft.Data.Sqlite.SqliteConnection]
    $SqliteConnection,

    [Parameter()]
    [switch]
    $KeepAlive,

    [Parameter()]
    [ValidateSet('UPDATE', 'UPSERT')]
    [string]
    $OnConflict = 'UPDATE'
  )

  if ($CaseSensitive) {
    Write-Warning 'CaseSensitive is currently not implemented in SqliteHelper.SetRow(). Using default matching behavior.'
  }
  if ($OnConflict -eq 'UPSERT') {
    Write-Warning 'OnConflict=UPSERT is not yet implemented in SqliteHelper.SetRow(). Falling back to UPDATE semantics.'
  }

  $ownsConnection = $false
  if (-not $PSBoundParameters.ContainsKey('SqliteConnection') -or $null -eq $SqliteConnection) {
    $SqliteConnection = [SqliteHelper]::NewConnection($SqliteDBConfig.ConnectionString)
    $ownsConnection = $true
  }

  try {
    [SqliteHelper]::SetRow($SqliteDBConfig, $TableName, [hashtable]$RowData, [hashtable]$ClauseData, $SqliteConnection)
  } finally {
    if ($ownsConnection -and -not $KeepAlive) {
      [SqliteHelper]::CloseConnection($SqliteConnection)
    }
  }
}
