
# [clihelper.sqlite](https://www.powershellgallery.com/packages/clihelper.sqlite)

🔥 Blazingly fast Sqlite module for using Microsoft.Data.Sqlite in your terminal.

[![Build Module](https://github.com/chadnpc/clihelper.sqlite/actions/workflows/build_module.yaml/badge.svg)](https://github.com/chadnpc/clihelper.sqlite/actions/workflows/build_module.yaml)
[![Downloads](https://img.shields.io/powershellgallery/dt/clihelper.sqlite.svg?style=flat&logo=powershell&color=blue)](https://www.powershellgallery.com/packages/clihelper.sqlite)


This module provides a set of cmdlets for working with SQLite databases in PowerShell.
It allows you to perform CRUD (Create, Read, Update, Delete) operations on SQLite databases Using a simple and intuitive syntax, leveraging the Microsoft.Data.Sqlite library.

The CRUD operations are designed to be easy to use, with support for various data formats such as DataTable, DataReader, DataSet, OrderedDictionary, and PSCustomObject, and do not
require the use of SQL queries directly, making it accessible for users who may not be familiar with SQL.

When the basic feature set is not enough, you can use the `Invoke-SqliteQuery` cmdlet to execute raw SQL queries directly against the database.

## Usage

```PowerShell
Install-Module clihelper.sqlite
```

then

```PowerShell
Import-Module clihelper.sqlite

# do stuff like:
Get-SqliteRow -SqliteDBConfig (Get-SqliteDBConfig -Path <path_to_config>) -TableName 'Employees' -ClauseData @{ Name = 'John Doe' } -As 'PSCustomObject'
```

## NOTES

  The module exposes type accelerators like [chadnpc.PSqlite.SQLiteDBConfig] and [chadnpc.PSqlite.SQLiteConnection]
  for easy access to the configuration and connection objects used in the cmdlets, mapping to internal PS classes.
  When using the `using` statement, you can access these types directly in your scripts ([SqliteDBConfig] and [SQLiteConnection]).

## License

This module is licensed under the [WTFPL License](LICENSE).
