function Out-Default {
	
	<#
    .SYNOPSIS
        Spelunking with Show-Object
    .DESCRIPTION
Spelunk [spi-luhngk], verb. To explore caves, especially as a hobby.

We must first recall that PowerShell pipelines are very different from, say, Linux pipelines. Rather than consisting of text, PowerShell objects are "three-dimensional" data structures that consist of properties (descriptive attributes), methods (actions the object can undertake), and events (actions that can be undertaken on the object). Collectively, these data elements are called object members.

For instance, take Get-Service. Unless you perform filtering, you receive an object collection as output. You probably know that Get-Member shows us the object's .NET Framework type name and its properties, methods, and events. Here's partial output from my Windows 8.1 administrative workstation running Windows Management Framework 5.0 Production Preview:

PS C:\> Get-Service | Get-Member

   TypeName: System.ServiceProcess.ServiceController

Name                  MemberType      Definition

—-                  ———-      ———-

Name                  AliasProperty   Name = ServiceName

RequiredServices      AliasProperty   RequiredServices…

Disposed              Event           System.EventHandler…

Close                 Method          void Close()

Continue              Method          void Continue()

PowerShell objects are instances of underlying .NET classes, and by default those classes are self-discovering through a process known as reflection. If you want to see everything about the previous ServiceController objects, pipe the Get-Member output to Format-List like so:

Get-Service | Get-Member | Format-List *

What I've told you means that, practically speaking, we do an awful lot of get-membering and format-listing when we need to look up specific property, method, or event values. Is there (banish the thought!) an easier-on-the-eyes graphical solution?
    .EXAMPLE
First we can locate the appropriate module:

Find-Module -Name *cookbook*

Cool. So Lee's module is named PowerShellCookbook, and it is stored on the PowerShell Gallery repository. Let's install it!

Install-Module -Name PowerShellCookbook -Force

As it happens, Show-Object is only one function among many that are contained in the PowerShellCookbook module. Run the following command to see them all:

Get-Command -Module PowerShellCookbook



Using the Show-Object Function

To use Show-Object, simply pipe your desired PowerShell object into the function like so:

Get-Service -Name Spooler | Show-Object

Take a look at the following Show-Object output, and I'll walk you through it.



The bottom pane (sadly unresizable) shows your ordinary Get-Member output. The upper pane allows you to quickly parse the object properties. For instance, we can expand each RequiredServices node to learn that the Print Spooler service in Windows 8.1 depends on a Remote Procedure Call (RPC) and HTTP services.

If you're of the mind to do so, you can inspect the Show-Object source code by visiting the book's website (see Program: Interactively View and Explore Objects) or by using PowerShell directly in your console:

(Get-Command -name Show-Object).Definition | Out-File 'C:\show-object-source.txt' | Notepad 'C:\show-object-source.txt'
Going further

One of the many things I love about the Windows PowerShell community is how friendly and helpful most people are. I don't want to draw comparisons to, say, the *NIX open-source community, but…well, let's just leave that alone.

That's all there is to it! 

    .FUNCTIONALITY
        General Command
    #>
    [CmdletBinding()]    
    param(
        
    [Parameter(ValueFromPipeline=$true)]
    [psobject]
    $InputObject
    )
    
    begin {
        $global:lastOutputCollection = New-Object Collections.ArrayList
        try {
             $outBuffer = $null
             if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
             {
                 $PSBoundParameters['OutBuffer'] = 1
             }
             $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Out-Default', [System.Management.Automation.CommandTypes]::Cmdlet)
             $scriptCmd = {& $wrappedCmd @PSBoundParameters }
             $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
             $steppablePipeline.Begin($true)
         } catch {
             throw
         }
         $invocation = Get-PSCallStack
    }
    
    process {
        try {
            $willProcess = $true 
            if ($_ -is [Management.Automation.ErrorRecord]) {
                $e = $_ 
                $i = $invocation

<#
                $cs = Get-PSCallStack
                $lastAction = Get-History -Count 1 
                if ($lastAction.CommandLine -like "*http*") {
                    if ($lastAction.CommandLine -like "`$*=*http*") {
                        $maybeUrl = $lastAction.CommandLine.Substring($lastAction.CommandLine.IndexOf("=") + 1).Trim()
                        $variableName = $lastAction.CommandLine.Substring(0, $lastAction.CommandLine.IndexOf("=") - 1).TrimStart('$')
                        if ($maybeUrl -like "http*") {
                            Set-Variable -Name $variableName -Value (
                                Get-Web -UseWebRequest $maybeUrl
                            ) -Option AllScope
                        }
                    } else {
                        Start-Process -FilePath $lastAction.CommandLine
                    }
                }
                $null = $null
                #>
             }
             $steppablePipeline.Process($_)
             $null = $global:lastOutputCollection.Add($_)
             $global:lastOutputItem = $_
        } catch {
             throw
        }
                     

    }
    
    end {
        if ($global:lastOutputCollection.Count) {
        $global:LastOutput = $global:lastOutputCollection        
        }
        
        try {
             $steppablePipeline.End()
        } catch {
             throw
        }

    }
}

