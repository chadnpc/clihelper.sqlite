function Get-SqliteRow {
  [CmdletBinding()]
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
    [Microsoft.Data.Sqlite.SqliteConnection]
    [ValidateNotNull()]
    $SqliteConnection,

    [Parameter()]
    [switch]
    $KeepAlive,

    [Parameter()]
    [switch]
    $CaseSensitive,

    [Parameter(DontShow)]
    [ValidateSet('DataTable', 'DataReader', 'DataSet', 'OrderedDictionary', 'PSCustomObject')]
    [string]
    $As = 'PSCustomObject'
  )

  if ($CaseSensitive) {
    Write-Warning 'CaseSensitive is currently not implemented in SqliteHelper.GetRow(). Using default matching behavior.'
  }

  $ownsConnection = $false
  if (-not $PSBoundParameters.ContainsKey('SqliteConnection') -or $null -eq $SqliteConnection) {
    $SqliteConnection = [SqliteHelper]::NewConnection($SqliteDBConfig.ConnectionString)
    $ownsConnection = $true
  }

  try {
    $result = [SqliteHelper]::GetRow($SqliteDBConfig, $TableName, [hashtable]$ClauseData, $SqliteConnection)

    if ($As -eq 'PSCustomObject') {
      return $result
    }

    $dataTable = [System.Data.DataTable]::new($TableName)
    foreach ($row in $result) {
      if ($dataTable.Columns.Count -eq 0) {
        foreach ($prop in $row.PSObject.Properties) {
          [void]$dataTable.Columns.Add($prop.Name)
        }
      }
      $dr = $dataTable.NewRow()
      foreach ($prop in $row.PSObject.Properties) {
        $dr[$prop.Name] = if ($null -eq $prop.Value) { [System.DBNull]::Value } else { $prop.Value }
      }
      [void]$dataTable.Rows.Add($dr)
    }

    switch ($As) {
      'DataTable' { return $dataTable }
      'OrderedDictionary' {
        foreach ($row in $dataTable.Rows) {
          $od = [System.Collections.Specialized.OrderedDictionary]::new()
          foreach ($col in $dataTable.Columns) {
            $od[$col.ColumnName] = if ($row[$col] -is [System.DBNull]) { $null } else { $row[$col.ColumnName] }
          }
          $od
        }
        return
      }
      'DataSet' {
        $ds = [System.Data.DataSet]::new()
        [void]$ds.Tables.Add($dataTable)
        return $ds
      }
      'DataReader' {
        # fallback convenience implementation
        return $dataTable.CreateDataReader()
      }
    }
  } finally {
    if ($ownsConnection -and -not $KeepAlive) {
      [SqliteHelper]::CloseConnection($SqliteConnection)
    }
  }
}
