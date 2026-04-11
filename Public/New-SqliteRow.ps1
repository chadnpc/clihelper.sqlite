function New-SqliteRow {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Creates in-memory object only.")]
  [CmdletBinding()][OutputType([PSCustomObject])]
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
  if (!$PSBoundParameters.ContainsKey('SqliteConnection') -or $null -eq $SqliteConnection) {
    $SqliteConnection = [SqliteHelper]::NewConnection($SqliteDBConfig.ConnectionString)
    $ownsConnection = $true
  }

  try {
    return [SqliteHelper]::NewRow($SqliteDBConfig, $TableName, [hashtable]$RowData, $SqliteConnection)
  } finally {
    if ($ownsConnection -and !$KeepAlive) {
      [SqliteHelper]::CloseConnection($SqliteConnection)
    }
  }
}
