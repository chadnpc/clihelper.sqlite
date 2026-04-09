function Close-PSqliteConnection
{
    <#
    .SYNOPSIS
        Closes the SQLite connections.

    .DESCRIPTION
        This function closes all SQLite connection pools, effectively closing all active connections to the SQLite database.

    .EXAMPLE
        Close-PSqliteConnection
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        # no parameter required
    )

    [Microsoft.Data.Sqlite.SqliteConnection]::ClearAllPools()
}
