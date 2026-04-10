using namespace System.Collections
using namespace System.Collections.Generic

function Set-SqliteRow {
  <#
    .SYNOPSIS
    Updates an existing row in a specified SQLite table based on the provided row data and clause data.

    .DESCRIPTION
    This function updates an existing row in a specified SQLite table using the provided row data.
    It constructs a SQL UPDATE query dynamically, applying a WHERE clause based on the keys and values in the ClauseData dictionary.

    .PARAMETER SqliteDBConfig
    A configuration object containing the SQLite database configuration specific to this module.
    This object should include the connection string and schema information for the database.

    .PARAMETER TableName
    The name of the table to update.

    .PARAMETER RowData
    A dictionary containing the data to update in the row.
    Keys are column names and values are the new values to set.

    .PARAMETER ClauseData
    A dictionary containing the criteria for selecting the row to update.
    Keys are column names and values are the values to match against those columns.

    .PARAMETER CaseSensitive
    A switch parameter that, when specified, makes the query case-sensitive.
    By default, the query is case-insensitive (using COLLATE NOCASE by default).

    .PARAMETER SqliteConnection
    A SqliteConnection object used to connect to the SQLite database.
    If not provided, a new connection will be created using the connection string from the SqliteDBConfig.

    .PARAMETER KeepAlive
    A switch parameter that, if specified, will keep the database connection open after the command completes.
    This is useful for scenarios where multiple commands will be executed in succession,
    preventing the overhead of opening and closing the connection repeatedly.
    If this parameter is not specified, the connection will be closed after the command completes.

    .PARAMETER OnConflict
    A parameter that specifies the behavior when a conflict occurs during the update.
    Possible values are 'UPDATE' (default) and 'UPSERT'.

    .EXAMPLE
    Set-SqliteRow -SqliteDBConfig $config -TableName 'Users' -RowData @{ Name = 'John'; Age = 30 } -ClauseData @{ Id = 1 }
    Updates the row in the 'Users' table where Id = 1, setting Name to 'John' and Age to 30.

    .NOTES
    This function is part of a module that provides CRUD operations for SQLite databases.
    It requires the SQLiteDBConfig object to be passed, which contains the connection string and schema information for the database.
    #>
  [CmdletBinding()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $true)]
    [SQLiteDBConfig]
    $SqliteDBConfig,

    [Parameter(Mandatory = $true)]
    [string]
    $TableName,

    [Parameter(Mandatory = $true)]
    [IDictionary]
    $RowData,

    [Parameter()]
    [IDictionary]
    $ClauseData,

    [Parameter()]
    [switch]
    # A switch parameter that makes the query case-sensitive.
    # By default, the query is case-insensitive (using COLLATE NOCASE by default).
    $CaseSensitive,

    [Parameter()]
    [Microsoft.Data.Sqlite.SqliteConnection]
    $SqliteConnection = (New-SqliteConnection -ConnectionString $SqliteDBConfig.ConnectionString),

    [Parameter()]
    [switch]
    $KeepAlive,

    [Parameter()]
    [ValidateSet('UPDATE', 'UPSERT')]
    [string]
    $OnConflict = 'UPDATE'
  )

  begin {
    if (!$SqliteConnection) {
      $SqliteConnection = New-SqliteConnection -ConnectionString $SqliteDBConfig.ConnectionString
    }

    $tableDefinition = $SqliteDBConfig.Schema.tables.Where{ $_.Name -eq $TableName }[0]
    $columnNames = $tableDefinition.Columns.Name
  }

  process {
    # [SqliteHelper]::SetRow(...)
  }
}
