using namespace Microsoft.Data.Sqlite

function Invoke-SqliteQuery {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [SqliteConnection]
    $SqliteConnection,

    [Parameter(Mandatory = $true)]
    [Alias('Query')]
    [string]
    $CommandText,

    [Parameter()]
    [ValidateSet('DataTable', 'DataReader', 'DataSet', 'OrderedDictionary', 'PSCustomObject')]
    [string]
    $As = 'DataTable',

    [Parameter()]
    [Type]
    $CastAs,

    [Parameter()]
    [System.Collections.IDictionary]
    $Parameters = @{},

    [Parameter()]
    [int]
    $CommandTimeout = 30,

    [Parameter()]
    [switch]
    $keepAlive
  )

  if ($CommandTimeout -ne 30) {
    Write-Warning 'SqliteHelper.InvokeSqliteQuery() currently does not expose CommandTimeout; using provider default timeout.'
  }

  $result = [SqliteHelper]::InvokeSqliteQuery($SqliteConnection, $CommandText, [hashtable]$Parameters, $As)

  if (!$keepAlive) {
    [SqliteHelper]::CloseConnection($SqliteConnection)
  }

  if ($PSBoundParameters.ContainsKey('CastAs') -and $null -ne $CastAs) {
    return ($result -as $CastAs)
  }

  return $result
}
