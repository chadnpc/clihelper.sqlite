function Get-SqliteDBMetadata {
  [OutputType([System.Collections.Specialized.OrderedDictionary])]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [Microsoft.Data.Sqlite.SqliteConnection]
    $SqliteConnection,

    [Parameter()]
    [string[]]
    $MetadataKey = @('*')
  )

  $metadataPresent = [SqliteHelper]::InvokeSqliteQuery(
    $SqliteConnection,
    'SELECT name from sqlite_schema WHERE name = @name COLLATE NOCASE',
    @{ name = '_metadata' },
    'DataTable'
  )

  if (!$metadataPresent -or $metadataPresent.Rows.Count -eq 0) {
    return $null
  }

  if ($MetadataKey -contains '*') {
    $query = 'SELECT key, value from _metadata;'
    $rows = [SqliteHelper]::InvokeSqliteQuery($SqliteConnection, $query, @{}, 'PSCustomObject')
  } else {
    $placeholders = @()
    $parameters = @{}
    for ($i = 0; $i -lt $MetadataKey.Count; $i++) {
      $pName = "k$i"
      $placeholders += "@$pName"
      $parameters[$pName] = $MetadataKey[$i]
    }

    $query = ('SELECT key, value from _metadata WHERE key IN ({0});' -f ($placeholders -join ', '))
    $rows = [SqliteHelper]::InvokeSqliteQuery($SqliteConnection, $query, $parameters, 'PSCustomObject')
  }

  $out = [System.Collections.Specialized.OrderedDictionary]::new()
  foreach ($row in $rows) {
    $out[$row.key] = $row.value
  }
  return $out
}
