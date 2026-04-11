#!/usr/bin/env pwsh
using namespace System.Collections
using namespace Microsoft.data.Sqlite
using namespace System.Collections.Generic


#region    Classes
enum DBMigrationMode {
  INCREMENTAL # Assume the database already exists and only apply changes "IF NOT EXISTS"
  CREATE      # Only create a new database if it doesn't exist, dropping any existing tables
  OVERWRITE   # remove the db file and create a new one
}

enum SqliteConstraintType {
  Index
  ForeignKey
  PrimaryKey
  Check
}

enum SqliteOrdering {
  ASC
  DESC
  NONE
}

enum SqliteTableOption {
  WithoutRowId
  Strict
}

enum SqliteType {
  TEXT
  INTEGER
  REAL
  BLOB
  NULL
}


class SQLiteConstraint {
  [SqliteConstraintType]$ConstraintType

  SQLiteConstraint() {
    # Default constructor
  }

  SQLiteConstraint([string]$constraintType) {
    $this.ConstraintType = $constraintType
  }

  SQLiteConstraint([SqliteConstraintType]$constraintType) {
    $this.ConstraintType = $constraintType
  }
}



class SqliteIndexConstraint : SqliteConstraint {
  [string]$Name # Name of the index
  [string]$Table # Name of the table on which the index is created
  [bool] $Unique = $false # Indicates if the index is unique
  [bool] $ifNotExists = $true # Indicates if the index is created with IF NOT EXISTS
  [string]$SchemaName # Schema name for the index (optional, default is null)
  [string[]]$Columns
  [string]$Where # Optional WHERE clause for partial indexes

  SqliteIndexConstraint() {
    # Default constructor
  }

  SqliteIndexConstraint([IDictionary]$Definition) {
    $this.Name = $Definition['Name']

    if (![string]::IsNullOrEmpty($Definition.Unique)) {

      [bool]$refValue = $this.Unique
      [void][bool]::TryParse($Definition['Unique'], [ref]$refValue)

      $this.Unique = $refValue
    }

    if (![string]::IsNullOrEmpty($Definition.ifNotExists)) {
      [void][bool]::TryParse($Definition['ifNotExists'], [ref]$this.ifNotExists)
    }

    $this.SchemaName = $Definition['SchemaName']
    $this.Table = $Definition['Table']
    $this.Columns = ($Definition['Columns'] -as [string[]]).Where({ $_ -ne $null }) # Ensure Columns is an array of strings
    if ($Definition.keys -contains 'Where') {

      $this.Where = $Definition['Where']
    }

    $this.ValidateDefinition()
  }

  [void] ValidateDefinition() {
    if (!$this.Name) {
      throw [System.ArgumentException]::new('Name is required for an index.')
    }

    if (!$this.Table) {
      throw [System.ArgumentException]::new('The Table''s name is required.')
    }

    if (!$this.Columns -or $this.Columns.Count -eq 0) {
      throw [System.ArgumentException]::new('At least one column is required for the index.')
    }
  }

  [string] CreateString() {
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    $sb.Append('CREATE')
    if ($this.Unique) {
      $sb.Append(' UNIQUE')
    }

    $sb.Append(' INDEX ')

    if ($this.ifNotExists) {
      $sb.Append('IF NOT EXISTS ')
    }

    if ($this.SchemaName) {
      $sb.Append('{0}.' -f $this.SchemaName)
    }

    $sb.Append(('{0} ON {1}(' -f $this.Name, $this.Table))

    if ($this.Columns -and $this.Columns.Count -gt 0) {
      $sb.Append(($this.Columns -join ', '))
    }

    $sb.Append(')')
    if ($this.WHERE) {
      $sb.Append((' WHERE {0}' -f $this.Where))
    }

    $sb.AppendLine(';')

    return $sb.ToString()
  }
}


class SqliteForeignKeyTableConstraint : SqliteConstraint {
  [string]$Name
  [string]$Table
  [string[]]$Columns
  [string]$ForeignTable
  [string[]]$ForeignColumns
  [string]$OnUpdate
  [string]$OnDelete
  [string]$Match = 'NONE' # Default match type is NONE

  SqliteForeignKeyTableConstraint() : base('ForeignKey') {
    # Default constructor
  }

  SqliteForeignKeyTableConstraint([System.Collections.IDictionary]$Definition) : base('ForeignKey') {
    $this.Name = $Definition['Name']
    $this.Table = $Definition['Table']
    $this.Columns = $Definition['Columns'] -as [string[]]
    $this.ForeignTable = $Definition['ForeignTable']
    $this.ForeignColumns = $Definition['ForeignColumns'] -as [string[]]

    if ($Definition.Keys -contains 'OnUpdate') {
      $this.OnUpdate = $Definition['OnUpdate']
    }

    if ($Definition.Keys -contains 'OnDelete') {
      $this.OnDelete = $Definition['OnDelete']
    }

    if ($Definition.Keys -contains 'Match') {
      $this.Match = $Definition['Match']
    }
    $this.ValidateDefinition()
  }

  [void] ValidateDefinition() {
    if (!$this.Name) {
      throw [System.ArgumentException]::new('Name is required for foreign key constraint.')
    }

    if (!$this.Table) {
      throw [System.ArgumentException]::new('Table is required for foreign key constraint.')
    }

    if (!$this.ForeignTable) {
      throw [System.ArgumentException]::new('ForeignTable is required for foreign key constraint.')
    }

    if (!$this.Columns -or $this.Columns.Count -eq 0) {
      throw [System.ArgumentException]::new('At least one column is required for foreign key constraint.')
    }

    if (!$this.ForeignColumns -or $this.ForeignColumns.Count -eq 0) {
      throw [System.ArgumentException]::new('At least one foreign column is required for foreign key constraint.')
    }
  }

  [string] ToString() {
    $this.ValidateDefinition()
    # Generate the SQL representation of the foreign key constraint
    # https://sqlite.org/syntax/table-constraint.html
    # https://sqlite.org/syntax/foreign-key-clause.html
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine(('CONSTRAINT {0} FOREIGN KEY (' -f $this.Name))
    [void]$sb.Append(('    {0}' -f ($this.Columns -join ', ')))
    [void]$sb.AppendLine(') REFERENCES')
    [void]$sb.Append(('    {0} (' -f $this.ForeignTable))

    [void]$sb.Append(('    {0})' -f ($this.ForeignColumns -join ', ')))
    if (![string]::IsNullOrEmpty($this.OnUpdate) -or ![string]::IsNullOrEmpty($this.OnDelete)) {
      if (![string]::IsNullOrEmpty($this.OnUpdate)) {
        [void]$sb.AppendLine((' ON UPDATE {0}' -f $this.OnUpdate.ToUpper()))
      }

      if (![string]::IsNullOrEmpty($this.OnDelete)) {
        [void]$sb.AppendLine((' ON DELETE {0}' -f $this.OnDelete.ToUpper()))
      }
    }

    # Add MATCH clause if needed
    if ($this.Match -and $this.Match -ne 'NONE') {
      [void]$sb.AppendLine((' MATCH {0}' -f $this.Match.ToUpper()))
    }
    [void]$sb.AppendLine(');')
    return $sb.ToString()
  }
}



class SqlitePrimaryKeyTableConstraint : SqliteConstraint {
  [string]$Name
  [string[]]$Columns
  [string]$ConflictClause = 'NONE' # Default conflict clause

  SqlitePrimaryKeyTableConstraint() : base('PrimaryKey') {
    # Default constructor
  }

  SqlitePrimaryKeyTableConstraint([IDictionary]$Definition) {
    $this.Name = $Definition['Name']
    $this.Columns = ($Definition['Columns'] -as [string[]]).Where({ $_ -ne $null }) # Ensure Columns is an array of strings
    if ($Definition.keys -contains 'ConflictClause') {

      $this.ConflictClause = $Definition['ConflictClause']
    }
  }

  [string]ToString() {
    return (
      'CONSTRAINT {0} PRIMARY KEY ({1}){2}' -f $this.Name, ($this.Columns -join ', '), $this.GetConflictClauseString()
    )
  }

  [string]GetConflictClauseString() {
    if ($this.ConflictClause -and $this.ConflictClause -ne "NONE") {
      return " ON CONFLICT {0}" -f $this.ConflictClause
    } else {
      return ''
    }
  }
}


class SqliteCheckTableConstraint : SqliteConstraint {
  [string]$TableName
  [string]$ColumnName
  [string]$CheckExpression # Expression for CHECK constraints


  SqliteCheckTableConstraint() : base('INDEX') {
    # Default constructor
  }

  SqliteCheckTableConstraint([System.Collections.IDictionary]$Definition) : base('INDEX') {
    $this.TableName = $Definition['TableName']
    $this.ColumnName = $Definition['ColumnName']
    $this.CheckExpression = $Definition['CheckExpression']

    $this.ValidateConstraint()
  }

  [void] ValidateConstraint() {
    if (!$this.TableName) {
      throw "TableName is required for CHECK constraints."
    }

    if (!$this.CheckExpression) {
      throw "CheckExpression is required for CHECK constraints."
    }
  }

  [string] ToString() {
    $this.ValidateConstraint() # Ensure the constraint is valid before converting to string
    return "CONSTRAINT {0} CHECK ({1})" -f $this.Name, $this.CheckExpression
  }
}


class SQLiteColumn {
  # In SQLite, PRIMARY KEY that are INTEGER are automatically indexed and auto-incremented (alias for ROWID)
  [string]$Name
  [SqliteType]$Type # SQLite data type

  #region PK Constraint
  [bool]$PrimaryKey = $false # Primary key column
  [System.Nullable[SqliteOrdering]]$PrimaryKeyOrder = $null # Order of the primary key (ASC or DESC)
  [bool]$AutoIncrement # Auto-incremented column (only for INTEGER PRIMARY KEY)
  #endregion

  [bool]$AllowNull = $true # Allow NULL values (if false, NOT NULL constraint is applied)

  [bool]$Unique = $false # Unique constraint
  [string]$UniqueConflictClause # Conflict clause for unique constraint (e.g., REPLACE, IGNORE)
  [string]$CheckExpression # Check constraint expression (for validation on write operations)
  [object]$DefaultValue # Default value for the column (can be a string, number, or expression). Default is null
  [string]$Collation # Collation for the column (e.g., BINARY, NOCASE, RTRIM)
  [bool]$Indexed = $false # Indexed column
  [string]$References # Foreign key reference (otherwise use a TableConstraint)

  SQLiteColumn() {
    # Default constructor
  }

  SQLiteColumn([IDictionary] $Definition) {
    $this.Name = $Definition['Name']
    $this.Type = $Definition['Type']
    # [void][bool]::TryParse($Definition['PrimaryKey'], [ref]$this.PrimaryKey)
    # $this.PrimaryKeyOrder = $Definition['PrimaryKeyOrder']

    if ($Definition.Keys -contains 'PrimaryKey' -and ![string]::IsNullOrEmpty($Definition['PrimaryKey'])) {

      #TryParse to handle cases where PrimaryKey is not a boolean

      [bool]$refValue = $this.PrimaryKey
      [void][bool]::TryParse($Definition['PrimaryKey'], [ref]$refValue)

      $this.PrimaryKey = $refValue
      if ($this.PrimaryKeyOrder -and $this.PrimaryKeyOrder -ne [SqliteOrdering]::None) {

        #Ensure PrimaryKeyOrder is set to None if PrimaryKey is false

        $this.PrimaryKeyOrder = 'NONE'
      }
    }

    if ($Definition.Keys -contains 'AutoIncrement' -and ![string]::IsNullOrEmpty($this.AutoIncrement) -and $this.Type -eq [SqliteType]::Integer) {
      Write-Host ('[WARNING] AutoIncrement is only applicable to INTEGER PRIMARY KEY columns. Setting AutoIncrement to false for column {0}.' -f $this.Name)

      [bool]$refValue = $this.AutoIncrement
      [void][bool]::TryParse($Definition['AutoIncrement'], [ref]$refValue)
      $this.AutoIncrement = $refValue
    }

    if ($Definition.keys -contains 'AllowNull' -and ![string]::IsNullOrEmpty($Definition['AllowNull'])) {

      #TryParse to handle cases where AllowNull is not a boolean
      [bool]$refValue = $this.AllowNull
      [void][bool]::TryParse($Definition['AllowNull'], [ref]$refValue)
      $this.AllowNull = $refValue
    }

    if ($Definition.Keys -contains 'Unique' -and ![string]::IsNullOrEmpty($Definition['Unique'])) {
      #TryParse to handle cases where Unique is not a boolean
      [bool]$refValue = $this.Unique
      $result = [bool]::TryParse($Definition['Unique'], [ref]$refValue)
      $this.Unique = $refValue
      #Log the conversion result
      Write-Debug -Message (
        'Unique constraint for column {0} set to {1} should be {2} (conversion success: {3})' -f $this.Name, $this.Unique, $Definition['Unique'], $result
      )
    }

    if ($Definition.Keys -contains 'UniqueConflictClause' -and ![string]::IsNullOrEmpty($Definition['UniqueConflictClause'])) {

      $this.UniqueConflictClause = $Definition['UniqueConflictClause']
    }

    if ($Definition.Keys -contains 'DefaultValue' -and ![string]::IsNullOrEmpty($Definition['DefaultValue'])) {

      $this.DefaultValue = $Definition['DefaultValue']
    }

    if ($Definition.Keys -contains 'Collation' -and ![string]::IsNullOrEmpty($Definition['Collation'])) {

      $this.Collation = $Definition['Collation']
    }

    if ($Definition.Keys -contains 'References' -and ![string]::IsNullOrEmpty($Definition['References'])) {

      $this.References = $Definition['References']
    }

    if ($Definition.Keys -contains 'CheckExpression' -and ![string]::IsNullOrEmpty($Definition['CheckExpression'])) {

      $this.CheckExpression = $Definition['CheckExpression']
    }
  }

  [void] ValidateDefinition() {
    if (!$this.Name) {
      throw [System.ArgumentException]::new('Column Name is required.')
    }

    if ($null -eq $this.Type) {
      throw [System.ArgumentException]::new('Column Type is required.')
    }

    if ($this.PrimaryKey -and $this.AllowNull) {
      Write-Host ('[WARNING] Although SQLite allows this, we recommend that Primary key columns do not allow NULL values.')
    }
  }

  [string] ToString() {
    $this.ValidateDefinition()
    # Generate the column definition string
    # https://sqlite.org/syntax/column-def.html
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append(('{0} {1}' -f $this.Name, $this.Type.ToString().ToUpper()))

    #region Column Constraints
    # https://sqlite.org/syntax/column-constraint.html
    if ($this.PrimaryKey) {
      [void]$sb.Append(' PRIMARY KEY')
      if ($this.PrimaryKeyOrder -and $this.PrimaryKeyOrder -ne [SqliteOrdering]::None) {

        #Append the order of the primary key if specified
        [void]$sb.Append((' {0}' -f $this.PrimaryKeyOrder.ToString().ToUpper()))
      }


      if ($this.AutoIncrement -or $this.Type -eq [SqliteType]::Integer) {

        #If the column is an INTEGER PRIMARY KEY, it is auto-incremented by default (alias for ROWID)
        [void]$sb.Append(' AUTOINCREMENT')
      }
    } elseif (!$this.AllowNull) {
      [void]$sb.Append(' NOT NULL')
    } elseif ($this.Unique) {
      [void]$sb.Append(' UNIQUE')
      if ($this.UniqueConflictClause) {
        [void]$sb.Append((' ON CONFLICT {0}' -f $this.UniqueConflictClause))
      }
    } elseif (![string]::IsNullOrEmpty($this.CheckExpression)) {
      [void]$sb.Append((' CHECK ({0})' -f $this.CheckExpression))
    } elseif (![string]::IsNullOrEmpty($this.DefaultValue)) {
      if ($this.DefaultValue -is [string]) {
        $useDefaultValue = $this.DefaultValue.Replace("'", "''") # Escape single quotes in string literals
      } else {
        $useDefaultValue = $this.DefaultValue
      }


      [void]$sb.Append((' DEFAULT {0}' -f $useDefaultValue))
    } elseif ($this.Collation) {
      [void]$sb.Append((' COLLATE {0}' -f $this.Collation))
    } elseif ($this.References) {
      $definition += " REFERENCES $($this.References)"
    }

    #endregion
    return $sb.ToString()
  }
}


class SqliteTable {
  [string]$Name
  [string]$Schema
  [bool] $ifNotExists = $true # If true, the table will only be created if it does not already exist
  [SqliteColumn[]]$Columns
  [SQLiteConstraint[]]$Constraints = @() # List of constraints for the table
  [SQLiteTableOption[]]$Options = @() # Options for the table, such as WithoutRowId or Strict

  SqliteTable() {
    # Default constructor
  }

  SqliteTable([System.Collections.IDictionary]$Definition) {
    $this.Name = $Definition['Name']
    if ($Definition.Keys -contains 'Schema') {
      $this.Schema = $Definition['Schema']
    }

    if ($Definition.keys -contains 'Columns') {
      foreach ($columnName in $Definition['Columns'].keys) {
        $currentColumn = $Definition['Columns'][$columnName]
        $currentColumn['Name'] = $columnName
        $this.Columns += [SqliteColumn]::new($currentColumn)
      }
    }

    if ($Definition.keys -contains 'Strict') {
      $this.Strict = $Definition['Strict']
    }
    if ($Definition.keys -contains 'Constraints') {
      foreach ($constraint in $Definition['Constraints']) {
        $constraint['Table'] = $this.Name # Ensure the constraint has the table name set
        switch ($constraint['Type']) {
          'ForeignKey' {
            $this.Constraints += [SqliteForeignKeyTableConstraint]::new($constraint)
          }
          'Check' {
            $this.Constraints += [SqliteCheckTableConstraint]::new($constraint)
          }
          'PrimaryKey' {
            $this.Constraints += [SqlitePrimaryKeyTableConstraint]::new($constraint)
          }
          'Index' {
            $this.Constraints += [SqliteIndexConstraint]::new($constraint)
          }
          default {
            Write-Host ('[WARNING] Unknown constraint type {0} for table {1}. Skipping.' -f $constraint['Type'], $this.Name)
          }
        }
      }
    }

    if ($Definition.keys -contains 'Options') {
      foreach ($option in $Definition['Options']) {
        $this.Options = ($option -as [SQLiteTableOption[]])
      }
    }
  }
  [void] ValidateDefinition() {
    if (!$this.Name) {
      throw [System.ArgumentException]::new('Table Name is required.')
    }
    if ($this.Columns.Count -eq 0) {
      throw [System.ArgumentException]::new('At least one column is required in the table definition.')
    }
    foreach ($column in $this.Columns) {
      $column.ValidateDefinition()
    }
  }

  [string] CreateString() {
    $this.ValidateDefinition()
    # Generate the CREATE TABLE statement
    # https://sqlite.org/syntax/create-table-stmt.html
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('CREATE')
    if ($this.Temporary) {
      [void]$sb.Append(' TEMPORARY')
    }

    [void]$sb.Append(' TABLE')

    if ($this.ifNotExists) {
      [void]$sb.Append(' IF NOT EXISTS ')
    }

    if ($this.Schema) {
      [void]$sb.Append(('{0}.' -f $this.Schema))
    }

    # Append the table name
    [void]$sb.Append((' {0}' -f $this.Name))
    # AS Select Statement goes here (not supported in this class yet)

    # Append the columns
    [void]$sb.AppendLine(' (')

    [int]$i = 0
    for ($i; $i -lt $this.Columns.Count; $i++) {
      # Write-Debug -Message ('Adding column {0} to table {1}' -f $this.Columns[$i].Name, $this.Name)
      [void]$sb.Append(('    {0}' -f $this.Columns[$i].ToString()))
      if ($i -lt ($this.Columns.Count - 1)) {

        #There's more columns to append, and it's not the first one
        [void]$sb.AppendLine(',')
      } else {
        [void]$sb.AppendLine('')
      }
    }

    [void]$sb.Append(')')

    if ($this.Options.Count -gt 0) {
      [void]$sb.Append(' ')
      [void]$sb.Append(($this.Options | ForEach-Object { $_.ToString() }) -join ', ')
    }

    $sb.AppendLine(';')
    return $sb.ToString()
  }
}


class SqliteDBSchema {
  [SqliteTable[]] $Tables = @()
  # [SqliteView[]] $Views
  [SqliteIndexConstraint[]] $Indexes = @()

  SqliteDBSchema() {
    # Default constructor
  }

  SqliteDBSchema([IDictionary] $Definition) {
    if ($Definition.Keys -contains 'Tables') {
      foreach ($tableName in $Definition['Tables'].Keys) {
        $currentTable = $Definition['Tables'][$tableName]
        $currentTable['Name'] = $tableName

        $this.Tables += [SqliteTable]::new($currentTable)
      }
    }

    if ($Definition.Keys -contains 'Indexes') {
      foreach ($indexName in $Definition['Indexes'].Keys) {
        $currentIndex = $Definition['Indexes'][$indexName]
        $currentIndex['Name'] = $indexName

        $this.Indexes += [SqliteIndexConstraint]::new($currentIndex)
      }
    }
  }

  [void] ValidateDefinition() {
    if (!$this.Tables -or $this.Tables.Count -eq 0) {
      throw [System.ArgumentException]::new('At least one table is required in the schema.')
    }

    foreach ($table in $this.Tables) {
      $table.ValidateDefinition()
    }

    if ($this.Indexes) {
      foreach ($index in $this.Indexes) {
        $index.ValidateDefinition()
      }
    }
  }

  [string] GetSchemaSDL() {
    $this.ValidateDefinition()
    [System.Text.StringBuilder]$sb = [System.Text.StringBuilder]::new()

    foreach ($table in $this.Tables) {
      $sb.AppendLine($table.CreateString())
    }

    foreach ($index in $this.Indexes) {
      $sb.AppendLine($index.CreateString())
    }

    return $sb.ToString()
  }
}


class SQLiteDBConfig {
  hidden [string] $ConfigurationFile
  [string] $DatabasePath
  [string] $DatabaseFile
  [string] $ConnectionString
  [string] $Version = '0'
  [SqliteDBSchema] $Schema


  SQLiteDBConfig() {
    # Default constructor
  }

  SQLiteDBConfig([string]$DatabasePath, [string]$DatabaseFile) {
    $this.DatabasePath = [SqliteHelper]::GetAbsolutePath([SqliteHelper]::ExpandString($DatabasePath))
    $this.DatabaseFile = [SqliteHelper]::ExpandString($DatabaseFile)
    $this.ConnectionString = 'Data Source={0};' -f ([IO.Path]::Combine($DatabasePath, $DatabaseFile))
  }

  SQLiteDBConfig([string]$StringInfo) {
    if (![IO.File]::Exists($StringInfo)) {
      #Test that the string is a valid connection string
      if ($StringInfo -notmatch '^Data Source=.*$') {
        throw "Invalid SQLite connection string format: $StringInfo"
      } else {

        $this.ConnectionString = $StringInfo
        return
      }
    } else {
      $configFileObject = Get-Content -Path $StringInfo | ConvertFrom-Yaml -Ordered

      $this.SetObjectProperties($configFileObject)
    }
  }

  SQLiteDBConfig ([System.Collections.IDictionary]$Definition) {
    $this.SetObjectProperties($Definition)
  }

  static [SQLiteDBConfig] Load([string]$ConfigFile) {
    $ConfigFile = [SqliteHelper]::GetAbsolutePath($ConfigFile)
    return [SQLiteDBConfig]::new($ConfigFile)
  }

  hidden SetObjectProperties([System.Collections.IDictionary]$Definition) {
    if ($Definition.Keys -contains 'DatabasePath') {
      $dbPath = [SqliteHelper]::ExpandString($Definition['DatabasePath'])
      $this.DatabasePath = [SqliteHelper]::GetAbsolutePath($dbPath)
    }

    if ($Definition.Keys -contains 'DatabaseFile') {
      $dbFile = [SqliteHelper]::ExpandString($Definition['DatabaseFile'])
      $this.DatabaseFile = $dbFile
    }

    if ($Definition.Keys -contains 'ConnectionString') {
      $this.ConnectionString = $Definition['ConnectionString']
    } else {
      if ($this.DatabaseFile) {
        $this.ConnectionString = 'Data Source={0};' -f (Join-Path -Path $this.DatabasePath -ChildPath $this.DatabaseFile)
      } else {
        throw [System.ArgumentException]::new('DatabasePath and DatabaseFile must be set to construct a valid connection string.')
      }
    }

    if ($Definition.Keys -contains 'Version') {
      $this.Version = $Definition['Version']
    }

    if ($Definition.Keys -contains 'Schema') {
      $this.Schema = [SqliteDBSchema]::new($Definition['Schema'])
    }
  }

  [string] GetDatabaseSDL() {
    if (!$this.Schema) {
      throw [System.InvalidOperationException]::new('Schema is not defined in the database configuration.')
    }

    return $this.Schema.GetSchemaSDL()
  }

  hidden [bool] databaseExists() {
    if ($this.ConnectionString -match ':memory:') {
      return $true
    } else {
      $dbFilePath = Join-Path -Path $this.DatabasePath -ChildPath $this.DatabaseFile
      return [IO.File]::Exists($dbFilePath)
    }
  }

  hidden [void] removeDatabase() {
    if ($this.databaseExists() -and $this.ConnectionString -notmatch ':memory:') {
      $DatabasePathFolder = [SqliteHelper]::GetAbsolutePath($this.DatabasePath)
      $dbFilePath = Join-Path -Path $DatabasePathFolder -ChildPath $this.DatabaseFile
      if (![IO.File]::Exists($dbFilePath)) {

        #can't find the file but $this.databaseExists() returned true
        Write-Host ('[WARNING] Database path does not exist: {0}.' -f $dbFilePath)
      } else {
        Write-Verbose -Message ('Removing existing database file at {0}' -f $dbFilePath)
        Remove-Item -Path $dbFilePath -Force -ErrorAction Stop
      }
    } else {
      Write-Verbose -Message 'No existing database file to remove.'
    }
  }

  hidden [void] UpdateDBSchema() {
    Write-Verbose -Message ('Creating database at {0}' -f (Join-Path -Path $this.DatabasePath -ChildPath $this.DatabaseFile))
    try {
      $dbconnection = [SqliteHelper]::NewConnection($this.ConnectionString)
      $dbconnection.Open()
      Write-Verbose -Message 'Database connection opened successfully.'
      $dbcommand = $this.GetDatabaseSDL()
      [SqliteHelper]::InvokeSqliteQuery($dbconnection, $dbcommand)
      [SqliteHelper]::InvokeSqliteQuery($dbconnection, 'CREATE TABLE IF NOT EXISTS _metadata (key TEXT PRIMARY KEY, value TEXT);')
      [SqliteHelper]::InvokeSqliteQuery($dbconnection, ('INSERT OR REPLACE INTO _metadata (key, value) VALUES (''version'', ''{0}'');' -f $this.Version))
      Write-Verbose -Message ('Database schema created successfully with version {0}.' -f $this.Version)
    } catch {
      throw [System.InvalidOperationException]::new('Failed to update database: ' + $_.Exception.Message)
    } finally {
      try {
        $dbconnection.Close()
        $dbconnection.Dispose()
        [Microsoft.Data.Sqlite.SqliteConnection]::ClearAllPools()
        Write-Verbose -Message 'Database connection closed.'
      } catch {
        Write-Host 'Failed to close the database connection.'
      }
    }
  }

  hidden [void] createDatabase() {
    Write-Verbose -Message 'Creating database...'
    $this.createDatabase($false, $false)
  }

  hidden [void] createDatabase([bool]$Force) {
    Write-Verbose -Message ('Creating database with Force={0}... (no schema update)' -f $Force)
    $this.createDatabase($Force, $true)
  }

  hidden [void] createDatabase([bool]$Force, [bool]$SkipSchemaUpdate) {
    if ($this.databaseExists() -and !$Force) {
      throw [System.InvalidOperationException]::new('Database already exists. Use Force to overwrite.')
    } elseif ($this.databaseExists() -and $Force) {
      $this.removeDatabase()
    } else {
      if (![IO.Directory]::Exists($this.DatabasePath)) {
        Write-Verbose -Message ('Creating database path at {0}' -f $this.DatabasePath)
        New-Item -Path $this.DatabasePath -ItemType Directory -Force | Out-Null
      }
    }

    if (!$SkipSchemaUpdate) {
      $this.updateDBSchema()
    }
  }
}


[SQLiteDBConfig]$script:DBConfig = $null
# Main class
class SqliteHelper {
  # --- Connection Management ---
  static [Microsoft.Data.Sqlite.SqliteConnection] NewConnection([string]$ConnectionString) {
    return [Microsoft.Data.Sqlite.SqliteConnection]::new($ConnectionString)
  }

  static [void] CloseConnection() {
    [Microsoft.Data.Sqlite.SqliteConnection]::ClearAllPools()
  }
  static [void] CloseConnection([Microsoft.Data.Sqlite.SqliteConnection]$Connection) {
    if ($null -ne $Connection) {
      $Connection.Close()
      if ($Connection.State.value__ -eq 1) {
        # FORCEFULLY update the state
        $Connection.PsObject.Properties.Add([PSNoteProperty]::new("State", [System.Data.ConnectionState]::Closed))
      }
      [Microsoft.Data.Sqlite.SqliteConnection]::ClearPool($Connection)
    }
  }

  # --- Configuration ---
  static [SQLiteDBConfig] GetSqliteDBConfig([string]$Path) {
    $absPath = [SqliteHelper]::GetAbsolutePath($Path)
    if (![IO.File]::Exists($absPath)) {
      throw [System.IO.FileNotFoundException]::new("Configuration file not found: $absPath")
    }
    return [SQLiteDBConfig]::new($absPath)
  }

  static [string] GetAbsolutePath([string]$Path) {
    $upath = [System.IO.Path]::IsPathRooted($Path) ? $Path : [PsModuleBase]::GetUnResolvedPath($Path)
    return $([IO.Path]::Exists($upath) ? $upath : [PsModuleBase]::GetResolvedPath($Path))
  }

  static [string] ExpandString([string]$String) {
    if ([string]::IsNullOrWhiteSpace($String)) { return $String }
    return [System.Environment]::ExpandEnvironmentVariables($String)
  }

  # --- Database Operations ---
  static [void] InitializeSqliteDatabase([SQLiteDBConfig]$Config) {
    [SqliteHelper]::InitializeSqliteDatabase($Config, [DBMigrationMode]::INCREMENTAL)
  }
  static [void] InitializeSqliteDatabase([SQLiteDBConfig]$Config, [DBMigrationMode]$MigrationMode) {
    [SqliteHelper]::InitializeSqliteDatabase($Config, $MigrationMode, $false)
  }
  static [void] InitializeSqliteDatabase([SQLiteDBConfig]$Config, [DBMigrationMode]$MigrationMode, [bool]$Force) {
    if ($null -eq $Config) { throw [ArgumentNullException]::new('Config') }

    if ($Force) { $MigrationMode = [DBMigrationMode]::OVERWRITE }

    if (!$Config.databaseExists()) {
      $Config.createDatabase()
    } else {
      # For simplicity in this refactor, we'll trigger update if versions differs or incremental is requested
      if ($MigrationMode -eq [DBMigrationMode]::INCREMENTAL) {
        $Config.updateDBSchema()
      } elseif ($MigrationMode -eq [DBMigrationMode]::OVERWRITE) {
        $Config.removeDatabase()
        $Config.createDatabase()
      }
    }
  }
  static [object] InvokeSqliteQuery([Microsoft.Data.Sqlite.SqliteConnection]$Connection, [string]$Query) {
    return [SqliteHelper]::InvokeSqliteQuery($Connection, $Query, @{}, 'DataTable')
  }
  static [object] InvokeSqliteQuery([Microsoft.Data.Sqlite.SqliteConnection]$Connection, [string]$Query, [hashtable]$Parameters = @{}, [string]$As) {
    if ($Connection.State -ne [System.Data.ConnectionState]::Open) {
      $Connection.Open()
    }

    $command = $Connection.CreateCommand()
    $command.CommandText = $Query
    foreach ($key in $Parameters.Keys) {
      $param = $command.CreateParameter()
      $param.ParameterName = $key
      $param.Value = $Parameters[$key]
      [void]$command.Parameters.Add($param)
    }

    try {
      if ($As -eq 'DataTable') {
        $reader = $command.ExecuteReader()
        $table = [System.Data.DataTable]::new()
        $table.Load($reader)
        return $table
      } elseif ($As -eq 'PSCustomObject') {
        $reader = $command.ExecuteReader()
        $table = [System.Data.DataTable]::new()
        $table.Load($reader)
        $results = New-Object System.Collections.Generic.List[PSCustomObject]
        foreach ($row in $table.Rows) {
          $obj = New-Object PSCustomObject
          foreach ($col in $table.Columns) {
            $val = if ($row[$col] -is [System.DBNull]) { $null } else { $row[$col] }
            $obj | Add-Member -MemberType NoteProperty -Name $col.ColumnName -Value $val
          }
          $results.Add($obj)
        }
        return $results.ToArray()
      } else {
        return $command.ExecuteNonQuery()
      }
    } finally {
      $command.Dispose()
    }
  }
  static [PSCustomObject[]] GetRow([SQLiteDBConfig]$Config, [string]$TableName, [hashtable]$ClauseData) {
    return [SqliteHelper]::GetRow($Config, $TableName, $ClauseData, $null)
  }
  static [PSCustomObject[]] GetRow([SQLiteDBConfig]$Config, [string]$TableName, [hashtable]$ClauseData, [Microsoft.Data.Sqlite.SqliteConnection]$Connection) {
    if ($null -eq $Connection) {
      $Connection = [SqliteHelper]::NewConnection($Config.ConnectionString)
    }

    $sqlParameters = @{}
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("SELECT * FROM $TableName WHERE 1=1")

    if ($null -ne $ClauseData) {
      foreach ($key in $ClauseData.Keys) {
        $paramName = $key -replace '[^a-zA-Z0-9]', ''
        if ($ClauseData[$key] -match '\*') {
          [void]$sb.AppendLine(" AND $key LIKE @$paramName COLLATE NOCASE")
          $sqlParameters[$paramName] = $ClauseData[$key] -replace '\*', '%'
        } else {
          [void]$sb.AppendLine(" AND $key = @$paramName COLLATE NOCASE")
          $sqlParameters[$paramName] = $ClauseData[$key]
        }
      }
    }

    return [SqliteHelper]::InvokeSqliteQuery($Connection, $sb.ToString(), $sqlParameters, 'PSCustomObject')
  }
  static [PSCustomObject] NewRow([SQLiteDBConfig]$Config, [string]$TableName, [hashtable]$RowData) {
    return [SqliteHelper]::NewRow($Config, $TableName, $RowData, $null)
  }
  static [PSCustomObject] NewRow([SQLiteDBConfig]$Config, [string]$TableName, [hashtable]$RowData, [Microsoft.Data.Sqlite.SqliteConnection]$Connection) {
    if ($null -eq $Connection) {
      $Connection = [SqliteHelper]::NewConnection($Config.ConnectionString)
    }

    $sb = [System.Text.StringBuilder]::new()
    $cols = $RowData.Keys -join ', '
    $params = $RowData.Keys.ForEach{ "@$($_ -replace '[^a-zA-Z0-9]', '')" } -join ', '
    [void]$sb.AppendLine("INSERT INTO $TableName ($cols) VALUES ($params) RETURNING *;")

    $sqlParameters = @{}
    foreach ($key in $RowData.Keys) {
      $sqlParameters[($key -replace '[^a-zA-Z0-9]', '')] = $RowData[$key]
    }

    $results = [SqliteHelper]::InvokeSqliteQuery($Connection, $sb.ToString(), $sqlParameters, 'PSCustomObject')
    if ($results.Count -gt 0) { return $results[0] } else { return $null }
  }
  static [void] SetRow([SQLiteDBConfig]$Config, [string]$TableName, [hashtable]$RowData, [hashtable]$ClauseData) {
    [SqliteHelper]::SetRow($Config, $TableName, $RowData, $ClauseData, $null)
  }
  static [void] SetRow([SQLiteDBConfig]$Config, [string]$TableName, [hashtable]$RowData, [hashtable]$ClauseData, [Microsoft.Data.Sqlite.SqliteConnection]$Connection) {
    if ($null -eq $Connection) {
      $Connection = [SqliteHelper]::NewConnection($Config.ConnectionString)
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("UPDATE $TableName SET ")
    $setParts = New-Object System.Collections.Generic.List[string]
    $sqlParameters = @{}

    foreach ($key in $RowData.Keys) {
      $pName = "set_$($key -replace '[^a-zA-Z0-9]', '')"
      $setParts.Add("$key = @$pName")
      $sqlParameters[$pName] = $RowData[$key]
    }
    [void]$sb.Append(($setParts -join ', '))
    [void]$sb.Append(" WHERE 1=1")

    foreach ($key in $ClauseData.Keys) {
      $pName = "where_$($key -replace '[^a-zA-Z0-9]', '')"
      [void]$sb.Append(" AND $key = @$pName")
      $sqlParameters[$pName] = $ClauseData[$key]
    }

    [void][SqliteHelper]::InvokeSqliteQuery($Connection, $sb.ToString(), $sqlParameters, 'NonQuery')
  }
  static [void] RemoveRow([SQLiteDBConfig]$Config, [string]$TableName, [hashtable]$ClauseData) {
    [SqliteHelper]::RemoveRow($Config, $TableName, $ClauseData, $null)
  }
  static [void] RemoveRow([SQLiteDBConfig]$Config, [string]$TableName, [hashtable]$ClauseData, [Microsoft.Data.Sqlite.SqliteConnection]$Connection) {
    if ($null -eq $Connection) {
      $Connection = [SqliteHelper]::NewConnection($Config.ConnectionString)
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("DELETE FROM $TableName WHERE 1=1")
    $sqlParameters = @{}

    foreach ($key in $ClauseData.Keys) {
      $pName = "where_$($key -replace '[^a-zA-Z0-9]', '')"
      [void]$sb.Append(" AND $key = @$pName")
      $sqlParameters[$pName] = $ClauseData[$key]
    }

    [void][SqliteHelper]::InvokeSqliteQuery($Connection, $sb.ToString(), $sqlParameters, 'NonQuery')
  }
}
#endregion Classes

# Types that will be available to users when they import the module.
# code to export the list of classes that should be available once the module is loaded
# The type accelerators created will be ModuleName.ClassName (to avoid conflicts with other modules until you use 'using moduleName'
$typestoExport = @(
  [SqliteHelper]
  [SqliteDBConfig]
  [SqliteDBSchema]
  [SqliteCheckTableConstraint]
  [SqlitePrimaryKeyTableConstraint]
  [SqliteForeignKeyTableConstraint]
  [SqliteIndexConstraint]
  [SqliteTable]
  [SqliteColumn]
  [SqliteType]
)


$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "Unable to register type accelerator '$($Type.FullName)'"
      'Accelerator already exists.'
    ) -join ' - '
    "TypeAcceleratorAlreadyExists $Message" | Write-Debug
  }
}
# Add type accelerators for every exportable type.
foreach ($Type in $typestoExport) {
  $TypeAcceleratorsClass::Add($Type.Name, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
  foreach ($Type in $typestoExport) {
    $TypeAcceleratorsClass::Remove($Type.Name)
  }
}.GetNewClosure();

$scripts = @();
$Public = Get-ChildItem "$PSScriptRoot/Public" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += Get-ChildItem "$PSScriptRoot/Private" -Filter "*.ps1" -ErrorAction SilentlyContinue
$scripts += $Public

foreach ($file in $scripts) {
  try {
    if ([string]::IsNullOrWhiteSpace($file.fullname)) { continue }
    . "$($file.fullname)"
  } catch {
    Write-Warning "Failed to import function $($file.BaseName): $_"
    $host.UI.WriteErrorLine($_)
  }
}

$Param = @{
  Cmdlet  = '*'
  Alias   = '*'
  Verbose = $false
}

if ($null -ne $Public -and $Public.Count -gt 0) {
  $Param.Function = $Public.BaseName
}

Export-ModuleMember @Param
