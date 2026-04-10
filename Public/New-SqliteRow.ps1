using namespace System.Collections
using namespace System.Collections.Generic

function New-SqliteRow {
  <#
    .SYNOPSIS
    Inserts a new row into a specified SQLite table.

    .DESCRIPTION
    This function inserts a new row into a specified SQLite table using the provided row data.

    .PARAMETER SqliteDBConfig
    A configuration object containing the SQLite database configuration specific to this module.
    This object should include the connection string and schema information for the database.

    .PARAMETER TableName
    The name of the table into which to insert the new row.

    .PARAMETER RowData
    A dictionary containing the data for the new row to be inserted.
    Keys are column names and values are the values to insert into those columns.

    .PARAMETER SqliteConnection
    A SqliteConnection object used to connect to the SQLite database.
    If not provided, a new connection will be created using the connection string from the SqliteDBConfig.

    .PARAMETER KeepAlive
    A switch parameter that, if specified, will keep the database connection open after the command completes.
    This is useful for scenarios where multiple commands will be executed in succession,
    preventing the overhead of opening and closing the connection repeatedly.
    If this parameter is not specified, the connection will be closed after the command completes.

    .EXAMPLE
    New-SqliteRow -SqliteDBConfig $config -TableName 'Users' -RowData @{ Name = 'John'; Age = 30; }

    .NOTES
    This function is part of a module that provides CRUD operations for SQLite databases.
    It requires the SQLiteDBConfig object to be passed, which contains the connection string
    and schema information for the database.
    #>
  [CmdletBinding()]
  [OutputType([Int64])]
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
    [Microsoft.Data.Sqlite.SqliteConnection]
    $SqliteConnection = (New-SqliteConnection -ConnectionString $SqliteDBConfig.ConnectionString),

    [Parameter()]
    [switch]
    $KeepAlive
  )

  begin {
    if (!$SqliteConnection) {
      $SqliteConnection = New-SqliteConnection -ConnectionString $SqliteDBConfig.ConnectionString
    }

    $tableDefinition = $SqliteDBConfig.Schema.tables.Where{ $_.Name -eq $TableName }[0]
    if (!$tableDefinition) {
      throw [System.ArgumentException]::new("Table '$TableName' does not exist in the database schema.")
    }

    $columnNames = $tableDefinition.Columns.Name
  }

  process {
    # [SqliteHelper]::NewRow(...)
  }

  end {
    if ($SqliteConnection -and $KeepAlive -eq $false) {
      try {
        [Microsoft.Data.Sqlite.SqliteConnection]::ClearPool($SqliteConnection)
        $SqliteConnection.Close()
        Write-Verbose -Message 'Database connection closed.'
      } catch {
        Write-Warning -Message 'Failed to close the database connection.'
      }
    }
  }
}
