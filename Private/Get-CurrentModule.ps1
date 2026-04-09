function Get-CurrentModule
{
    <#
      .SYNOPSIS
      This is a Private function to always be able to retrieve the module info even outside of a function (i.e. PSM1)

      .DESCRIPTION
      This function is only meant to be used from the psm1, hence not exported.

      .EXAMPLE
      $null = Get-CurrentModule

      #>
    [OutputType([System.Management.Automation.PSModuleInfo])]
    param
    ()

    # Get the current module
    $MyInvocation.MyCommand.ScriptBlock.Module
}

