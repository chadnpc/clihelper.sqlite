function Get-SqliteDBConfig {
  [CmdletBinding()]
  [OutputType([SQLiteDBConfig])]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias('ConfigFile')]
    [string]
    $Path
  )
  end {
    return [SqliteHelper]::GetSqliteDBConfig($Path)
  }
}
