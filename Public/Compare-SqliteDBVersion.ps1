function Compare-SqliteDBVersion {
  [CmdletBinding()]
  [OutputType([object])]
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [SqliteDBConfig]
    $DatabaseConfig,

    [Parameter()]
    [string]
    $ExpectedVersion = $DatabaseConfig.version
  )

  $result = [ordered]@{
    CurrentVersion  = $null
    ExpectedVersion = $ExpectedVersion
    IsDeployed      = $false
    direction       = '!='
    Reasons         = @()
    PSTypeName      = 'Clihelper.Sqlite.DBVersionComparisonResult'
  }

  if (!$DatabaseConfig.databaseExists()) {
    $result.Reasons += 'Database does not exist.'
    return [PSCustomObject]$result
  }

  $connection = [SqliteHelper]::NewConnection($DatabaseConfig.ConnectionString)
  try {
    $metadata = Get-SqliteDBMetadata -SqliteConnection $connection -MetadataKey 'version'
  } finally {
    [SqliteHelper]::CloseConnection($connection)
  }

  if ($null -eq $metadata -or [string]::IsNullOrWhiteSpace($metadata['version'])) {
    $result.Reasons += 'Database version is not set in metadata.'
    return [PSCustomObject]$result
  }

  $current = [string]$metadata['version']
  $result.CurrentVersion = $current
  $result.IsDeployed = $true

  if ([string]::IsNullOrWhiteSpace($ExpectedVersion)) {
    $result.ExpectedVersion = $null
    $result.direction = '>'
    $result.Reasons += 'Expected version is not set.'
    return [PSCustomObject]$result
  }

  if ($current -eq $ExpectedVersion) {
    $result.direction = '=='
    $result.Reasons += ('Database version matches expected version: {0}' -f $ExpectedVersion)
    return [PSCustomObject]$result
  }

  try {
    $currentVersion = [version]($current -replace '-.*', '')
    $expected = [version]($ExpectedVersion -replace '-.*', '')

    if ($currentVersion -lt $expected) {
      $result.direction = '<'
    } elseif ($currentVersion -gt $expected) {
      $result.direction = '>'
    }
  } catch {
    $result.direction = '!='
    $result.Reasons += 'Non-standard version format detected; using string inequality.'
  }

  $result.Reasons += ('Database version comparison: {0} {1} {2}' -f $current, $result.direction, $ExpectedVersion)
  return [PSCustomObject]$result
}
