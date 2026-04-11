# [clihelper.sqlite](https://www.powershellgallery.com/packages/clihelper.sqlite)

Blazingly fast SQLite module for using Microsoft.Data.Sqlite in PowerShell scripts.

[![Downloads](https://img.shields.io/powershellgallery/dt/clihelper.sqlite.svg?style=flat&logo=powershell&color=blue)](https://www.powershellgallery.com/packages/clihelper.sqlite)

This module provides PowerShell classes and cmdlets for working with SQLite databases. It is designed for developers who want programmatic access to SQLite via `[SqliteHelper]` static methods and schema classes, with optional cmdlet wrappers for interactive use.

## Installation

```PowerShell
Install-Module clihelper.sqlite
```

## Quick Start

In your script:

```PowerShell
using module clihelper.sqlite

# Create an in-memory connection
$conn = [SqliteHelper]::NewConnection('Data Source=:memory:;Cache=Shared;')

# Create a table
[SqliteHelper]::InvokeSqliteQuery($conn, 'CREATE TABLE Users (id INTEGER PRIMARY KEY, name TEXT UNIQUE);')

# Insert a row
[SqliteHelper]::InvokeSqliteQuery($conn, "INSERT INTO Users (name) VALUES ('Alice');")

# Query rows
$rows = [SqliteHelper]::InvokeSqliteQuery($conn, 'SELECT * FROM Users;', @{}, 'PSCustomObject')
$rows.name  # Alice

# Clean up
[SqliteHelper]::CloseConnection($conn)
```

## Schema Definition

Build your database schema using PowerShell classes:

```PowerShell
using module clihelper.sqlite

$columns = @(
  [SqliteColumn]@{ Name = 'id';     Type = [SqliteType]::INTEGER; PrimaryKey = $true; AutoIncrement = $true; AllowNull = $false }
  [SqliteColumn]@{ Name = 'name';   Type = [SqliteType]::TEXT; Unique = $true; AllowNull = $false }
  [SqliteColumn]@{ Name = 'email';  Type = [SqliteType]::TEXT; AllowNull = $true }
  [SqliteColumn]@{ Name = 'guild';  Type = [SqliteType]::INTEGER; AllowNull = $true }
)

$table = [SqliteTable]@{ Name = 'Users'; Columns = $columns; ifNotExists = $true }
$schema = [SqliteDBSchema]@{ Tables = @($table) }

# Generate the DDL
$schema.GetSchemaSDL()
```

## Database Configuration and Initialization

Create a `[SQLiteDBConfig]` to manage database lifecycle:

```PowerShell
using module clihelper.sqlite

# From a connection string (in-memory or file-based)
$config = [SQLiteDBConfig]::new('Data Source=C:\Data\mydb.sqlite;')

# Or from a YAML config file
$config = [SQLiteDBConfig]::Load('C:\Config\myapp.SqliteConfig.yml')

# Attach a schema and initialize
$config.Schema = $schema
$config.Version = '1.0'
[SqliteHelper]::InitializeSqliteDatabase($config)

# Overwrite mode (drops and recreates)
[SqliteHelper]::InitializeSqliteDatabase($config, [DBMigrationMode]::OVERWRITE, $true)
```

## CRUD Operations

Use `[SqliteHelper]` static methods for Create, Read, Update, and Delete:

```PowerShell
using module clihelper.sqlite

$config = [SQLiteDBConfig]::new('Data Source=C:\Data\mydb.sqlite;')

# Insert
$row = [SqliteHelper]::NewRow($config, 'Users', @{ name = 'Alice'; email = 'alice@example.com' })
# Returns: PSCustomObject with the inserted row (including auto-generated id)

# Select
$rows = [SqliteHelper]::GetRow($config, 'Users', @{ name = 'Alice' })
# LIKE wildcards: use * which maps to SQL %
$rows = [SqliteHelper]::GetRow($config, 'Users', @{ name = 'Ali*' })

# Update
[SqliteHelper]::SetRow($config, 'Users', @{ email = 'newalice@example.com' }, @{ name = 'Alice' })

# Delete
[SqliteHelper]::RemoveRow($config, 'Users', @{ name = 'Alice' })
```

### With an Explicit Connection

Pass an open connection to reuse it across operations (required for in-memory databases):

```PowerShell
$conn = [SqliteHelper]::NewConnection('Data Source=:memory:;Cache=Shared;')

# Create the table first
[SqliteHelper]::InvokeSqliteQuery($conn, 'CREATE TABLE Users (id INTEGER PRIMARY KEY, name TEXT);')

# CRUD with explicit connection
$row = [SqliteHelper]::NewRow($config, 'Users', @{ name = 'Bob' }, $conn)
$rows = [SqliteHelper]::GetRow($config, 'Users', @{ name = 'Bob' }, $conn)

# Clean up
[SqliteHelper]::CloseConnection($conn)
```

## Raw SQL Queries

Execute parameterized queries with `InvokeSqliteQuery`:

```PowerShell
using module clihelper.sqlite

$conn = [SqliteHelper]::NewConnection('Data Source=C:\Data\mydb.sqlite;')

# Parameterized query (returns PSCustomObject[])
$rows = [SqliteHelper]::InvokeSqliteQuery(
  $conn,
  'SELECT * FROM Users WHERE guild = @guild AND name LIKE @name;',
  @{ guild = 1; name = '%Ali%' },
  'PSCustomObject'
)

# Non-query (returns affected row count)
$affected = [SqliteHelper]::InvokeSqliteQuery(
  $conn,
  "DELETE FROM Users WHERE name = @name;",
  @{ name = 'Alice' }
)

# Default returns DataTable
$dt = [SqliteHelper]::InvokeSqliteQuery($conn, 'SELECT * FROM Users;')

[SqliteHelper]::CloseConnection($conn)
```

## Configuration from YAML

Use a YAML config file for database and schema definitions:

```PowerShell
using module clihelper.sqlite

# Load config from YAML file
$config = [SqliteHelper]::GetSqliteDBConfig('C:\Config\myapp.SqliteConfig.yml')

# Or use the type accelerator
$config = [SQLiteDBConfig]::Load('C:\Config\myapp.SqliteConfig.yml')

# Initialize the database
[SqliteHelper]::InitializeSqliteDatabase($config)
```

## Type Accelerators

The module registers the following type accelerators for use in scripts:

| Accelerator | Full Type |
|---|---|
| `[SqliteHelper]` | Main utility class with static CRUD and query methods |
| `[SQLiteDBConfig]` | Database configuration and lifecycle management |
| `[SqliteDBSchema]` | Schema definition (collection of tables and indexes) |
| `[SqliteTable]` | Table definition with columns and constraints |
| `[SqliteColumn]` | Column definition with type and constraints |
| `[SqliteIndexConstraint]` | Index constraint |
| `[SqliteForeignKeyTableConstraint]` | Foreign key constraint |
| `[SqlitePrimaryKeyTableConstraint]` | Primary key constraint |
| `[SqliteCheckTableConstraint]` | Check constraint |

## Cmdlet Reference

For interactive use, the module also exports cmdlet wrappers:

| Cmdlet | Class Method |
|---|---|
| `New-SqliteConnection` | `[SqliteHelper]::NewConnection()` |
| `Close-SqliteConnection` | `[SqliteHelper]::CloseConnection()` |
| `Get-SqliteDBConfig` | `[SqliteHelper]::GetSqliteDBConfig()` |
| `Get-SqliteDBConfigFile` | `[SqliteHelper]::GetAbsolutePath()` |
| `Initialize-SqliteDatabase` | `[SqliteHelper]::InitializeSqliteDatabase()` |
| `Invoke-SqliteQuery` | `[SqliteHelper]::InvokeSqliteQuery()` |
| `Get-SqliteRow` | `[SqliteHelper]::GetRow()` |
| `New-SqliteRow` | `[SqliteHelper]::NewRow()` |
| `Set-SqliteRow` | `[SqliteHelper]::SetRow()` |
| `Remove-SqliteRow` | `[SqliteHelper]::RemoveRow()` |
| `Compare-SqliteDBVersion` | Uses `NewConnection` + `InvokeSqliteQuery` |
| `Get-SqliteDBMetadata` | Uses `InvokeSqliteQuery` internally |

## License

This module is licensed under the [WTFPL License](LICENSE).