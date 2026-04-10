function Get-SqliteDBConfig {
  [CmdletBinding()]
  [OutputType([SQLiteDBConfig])]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias('ConfigFile')]
    [string]
    $Path
  )

  return [SqliteHelper]::GetSqliteDBConfig($Path)
}
