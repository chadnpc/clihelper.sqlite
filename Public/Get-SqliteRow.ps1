function Get-SqliteRow {
  <#
  .SYNOPSIS
  Retrieves rows from a SQLite database table or view based on specified criteria.

  .DESCRIPTION
  This function retrieves the rows from a specified SQLite database table based on
  the provided criteria (ClauseData).
  It constructs a SQL query dynamically retrieving all columns (SELECT * FROM tableName)
  applying a WHERE clause based on the keys and values in the ClauseData dictionary.
  If a key in ClauseData matches a column name in the table, it will be used
  to filter the results. If the value contains an asterisk (*), it will be treated
  as a wildcard for a LIKE query (replaced with %).
  If the value does not contain an asterisk, it will be treated as an exact match (=).
  The function supports special cases for keys ending with 'Before' or 'After', allowing
  filtering based on date or numeric values.
  The function supports case sensitivity when specified.

  .PARAMETER SqliteDBConfig
    A configuration object containing the SQLite database configuration specific to this module.

  .PARAMETER TableName
    The name of the table or view from which to retrieve rows.

  .PARAMETER ClauseData
    A dictionary containing the criteria for filtering rows, where keys are column names
    and values are the values to match against those columns.
    The keys can also include special suffixes like 'Before' or 'After'
    to indicate date or numeric comparisons.
    If a value contains an asterisk (*), it will be treated as a wildcard for a LIKE query
    (replaced with %). If it does not contain an asterisk, it will be treated as an exact match (=).

  .PARAMETER SqliteConnection
    An existing SQLite connection object. If not provided, a new connection will be created
    using the connection string from the SqliteDBConfig.

  .PARAMETER KeepAlive
    A switch parameter that, when specified, keeps the SQLite connection open after the query execution.
    This is useful for scenarios where multiple queries will be executed in succession,
    preventing the overhead of opening and closing the connection repeatedly.
    It's also mandatory when using a :memory: database connection, otherwise the connection will be closed
    after the query execution, and the database dropped.

  .PARAMETER CaseSensitive
    A switch parameter that, when specified, makes the query case-sensitive.
    By default, the query is case-insensitive (using COLLATE NOCASE by default).

  .PARAMETER As
    Specifies the format in which the results should be returned.
    Valid values are 'DataTable', 'DataReader', 'DataSet', 'OrderedDictionary', and 'PSCustomObject'.
    The default value is 'PSCustomObject', which returns the results as PowerShell custom objects.

  .EXAMPLE
    Get-SqliteRow -SqliteDBConfig $config -TableName 'Users' -ClauseData @{ Name = 'John*'; Age = 30 }

  .NOTES
    This function is part of a module that provides CRUD operations for SQLite databases.
    It requires the SQLiteDBConfig object to be passed, which contains the connection string
    and schema information for the database.
    The function uses the Microsoft.Data.Sqlite library for database operations.
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [SQLiteDBConfig]
    # Configuration object containing the SQLite database configuration specific to this module.
    # This object should include the connection string and schema information for the database.
    $SqliteDBConfig,

    [Parameter(Mandatory = $true)]
    [string]
    # Name of the table or view to query.
    $TableName,

    [Parameter()]
    [IDictionary]
    # A dictionary containing the criteria for filtering rows.
    # Keys are column names and values are the values to match against those columns.
    $ClauseData,

    [Parameter()]
    [Microsoft.Data.Sqlite.SqliteConnection]
    # An existing SQLite connection object.
    # If not provided, a new connection will be created using the connection string from the SqliteDBConfig.
    [ValidateNotNull()]
    $SqliteConnection = (New-SqliteConnection -ConnectionString $SqliteDBConfig.ConnectionString),

    [Parameter()]
    [switch]
    # A switch parameter that keeps the SQLite connection open after the query execution.
    # This is useful for scenarios where multiple queries will be executed in succession,
    # preventing the overhead of opening and closing the connection repeatedly.
    # It's also mandatory when using a :memory: database connection, otherwise the connection will be closed
    # after the query execution, and the database dropped.
    $KeepAlive,

    [Parameter()]
    [switch]
    # A switch parameter that makes the query case-sensitive.
    # By default, the query is case-insensitive (using COLLATE NOCASE by default).
    $CaseSensitive,

    [Parameter(DontShow)]
    [ValidateSet('DataTable', 'DataReader', 'DataSet', 'OrderedDictionary', 'PSCustomObject')]
    [string]
    # Specifies the format in which the results should be returned.
    # Valid values are 'DataTable', 'DataReader', 'DataSet', 'Ordered
    $As = 'PSCustomObject'
  )

  begin {
    if (!$SqliteConnection) {
      $SqliteConnection = New-SqliteConnection -ConnectionString $SqliteDBConfig.ConnectionString
    }

    $tableDefinition = $SqliteDBConfig.Schema.tables.Where{ $_.Name -eq $TableName }[0]
    $columnNames = $tableDefinition.Columns.Name
  }

  process {
    # [SqliteHelper]::GetSqliteRow(..)
  }

  end {
    if (!$KeepAlive) {
      try {
        $SqliteConnection.Close()
        [Microsoft.Data.Sqlite.SqliteConnection]::ClearPool($SqliteConnection)
        Write-Debug -Message 'Database connection closed.'
      } catch {
        Write-Warning -Message 'Failed to close the database connection.'
      }
    }
  }
}
