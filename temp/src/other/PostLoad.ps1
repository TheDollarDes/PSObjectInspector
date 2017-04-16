
# Use this variable for any path-sepecific actions (like loading dlls and such) to ensure it will work in testing and after being built
$MyModulePath = $(
    Function Get-ScriptPath {
        $Invocation = (Get-Variable MyInvocation -Scope 1).Value
        if($Invocation.PSScriptRoot) {
            $Invocation.PSScriptRoot
        }
        Elseif($Invocation.MyCommand.Path) {
            Split-Path $Invocation.MyCommand.Path
        }
        elseif ($Invocation.InvocationName.Length -eq 0) {
            (Get-Location).Path
        }
        else {
            $Invocation.InvocationName.Substring(0,$Invocation.InvocationName.LastIndexOf("\"));
        }
    }

    Get-ScriptPath
)


if ($host.Name -ne "Windows PowerShell ISE Host")
{
    Write-Warning "Runtime Inspector is a PowerShell ISE Addon"    
} else {
Add-Type -Path $MyModulePath\RuntimeInspector.dll -PassThru
$typeRuntimeInspector = [IseAddons.VariableExplorer]
$psISE.CurrentPowerShellTab.VerticalAddOnTools.Add("RuntimeInspector", $typeRuntimeInspector, $true)
}
#region Module Cleanup
$ExecutionContext.SessionState.Module.OnRemove = {
    # Action to take if the module is removed

    $RITab =  $psISE.CurrentPowerShellTab.VerticalAddOnTools | Where-Object { $_.Name -eq "RuntimeInspector" } 
    $OITab =  $psISE.CurrentPowerShellTab.HorizontalAddOnTools | Where-Object { $_.Name -eq "OutputInspector" } 

   if ($RITab) {
        $null = $psISE.CurrentPowerShellTab.VerticalAddOnTools.Remove($RITab)
    }

   if ($OITab) {
        $null = $psISE.CurrentPowerShellTab.HorizontalAddOnTools.Remove($OITab)
    }

}

$null = Register-EngineEvent -SourceIdentifier ( [System.Management.Automation.PsEngineEvent]::Exiting ) -Action {
    # Action to take if the whole pssession is killed
}
#endregion Module Cleanup

# Exported members
#Export-ModuleMember -Variable SomeVariable -Function  *
