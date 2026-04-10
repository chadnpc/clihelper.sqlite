function New-SqliteRow {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
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
    [Microsoft.Data.Sqlite.SqliteConnection]
    $SqliteConnection,

    [Parameter()]
    [switch]
    $KeepAlive
  )

  $ownsConnection = $false
  if (-not $PSBoundParameters.ContainsKey('SqliteConnection') -or $null -eq $SqliteConnection) {
    $SqliteConnection = [SqliteHelper]::NewConnection($SqliteDBConfig.ConnectionString)
    $ownsConnection = $true
  }

  try {
    return [SqliteHelper]::NewRow($SqliteDBConfig, $TableName, [hashtable]$RowData, $SqliteConnection)
  } finally {
    if ($ownsConnection -and -not $KeepAlive) {
      [SqliteHelper]::CloseConnection($SqliteConnection)
    }
  }
}
