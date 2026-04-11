using namespace Microsoft.Data.Sqlite
function New-SqliteConnection {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Creates in-memory object only.")]
  [CmdletBinding(DefaultParameterSetName = 'byConnectionString')]
  [OutputType([Microsoft.Data.Sqlite.SqliteConnection])]
  param (
    [Parameter(ParameterSetName = 'byConnectionString')]
    [string]
    $ConnectionString = 'Data Source=:memory:;Cache=Shared;',

    [Parameter(ParameterSetName = 'byDatabasePath')]
    [string]
    $DatabasePath = (Get-Location).Path,

    [Parameter(ParameterSetName = 'byDatabasePath', Mandatory = $true)]
    [string]
    $DatabaseFile
  )

  switch ($PSCmdlet.ParameterSetName) {
    'byConnectionString' {
      return [SqliteHelper]::NewConnection($ConnectionString)
    }

    'byDatabasePath' {
      if (!(Test-Path -Path $DatabasePath)) {
        $null = New-Item -Path $DatabasePath -ItemType Directory -Force
      }

      $dataSource = Join-Path -Path $DatabasePath -ChildPath $DatabaseFile
      if (!(Test-Path -Path $dataSource)) {
        $null = New-Item -Path $dataSource -ItemType File -Force
      }

      return [SqliteHelper]::NewConnection(('Data Source={0};' -f $dataSource))
    }
  }
}
