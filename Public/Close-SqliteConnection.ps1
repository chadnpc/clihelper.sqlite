function Close-SqliteConnection {
  # .SYNOPSIS
  # Closes the SQLite connections.

  # .DESCRIPTION
  # This function closes all SQLite connection pools, effectively closing all active connections to the SQLite database.

  # .EXAMPLE
  # Close-SqliteConnection
  [CmdletBinding()]
  [OutputType([void])]
  param (
    # no parameter required
  )

  [SqliteHelper]::CloseConnection()
}
