function Initialize-SqliteDatabase {
  [CmdletBinding(DefaultParameterSetName = 'byPath')]
  [OutputType([void])]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'byPath')]
    [Alias('DatabaseConfigPath')]
    [string]
    $Path,

    [Parameter(Mandatory = $true, ParameterSetName = 'byConfig')]
    [Alias('SqliteDBConfig')]
    [SQLiteDBConfig]
    $DatabaseConfig,

    [Parameter()]
    [DBMigrationMode]
    $MigrationMode = [DBMigrationMode]::INCREMENTAL,

    [Parameter()]
    [switch]
    $Force
  )

  if ($PSCmdlet.ParameterSetName -eq 'byPath') {
    $DatabaseConfig = [SqliteHelper]::GetSqliteDBConfig($Path)
  }

  [SqliteHelper]::InitializeSqliteDatabase($DatabaseConfig, $MigrationMode, $Force.IsPresent)
}
