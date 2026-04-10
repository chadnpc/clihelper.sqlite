function Remove-SqliteRow {
  [CmdletBinding()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $true)]
    [SQLiteDBConfig]
    $SqliteDBConfig,

    [Parameter(Mandatory = $true)]
    [string]
    $TableName,

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
    $KeepAlive
  )

  if ($CaseSensitive) {
    Write-Warning 'CaseSensitive is currently not implemented in SqliteHelper.RemoveRow(). Using default matching behavior.'
  }

  $ownsConnection = $false
  if (-not $PSBoundParameters.ContainsKey('SqliteConnection') -or $null -eq $SqliteConnection) {
    $SqliteConnection = [SqliteHelper]::NewConnection($SqliteDBConfig.ConnectionString)
    $ownsConnection = $true
  }

  try {
    [SqliteHelper]::RemoveRow($SqliteDBConfig, $TableName, [hashtable]$ClauseData, $SqliteConnection)
  } finally {
    if ($ownsConnection -and -not $KeepAlive) {
      [SqliteHelper]::CloseConnection($SqliteConnection)
    }
  }
}
