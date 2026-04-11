function Remove-SqliteRow {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Creates in-memory object only.")]
  [CmdletBinding()][OutputType([void])]
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
  if (!$PSBoundParameters.ContainsKey('SqliteConnection') -or $null -eq $SqliteConnection) {
    $SqliteConnection = [SqliteHelper]::NewConnection($SqliteDBConfig.ConnectionString)
    $ownsConnection = $true
  }

  try {
    [SqliteHelper]::RemoveRow($SqliteDBConfig, $TableName, [hashtable]$ClauseData, $SqliteConnection)
  } finally {
    if ($ownsConnection -and !$KeepAlive) {
      [SqliteHelper]::CloseConnection($SqliteConnection)
    }
  }
}
