
Function Show-Object-Flat {
    <#
    .SYNOPSIS
        Flatten an object to simplify discovery of data
    .DESCRIPTION
        Flatten an object.  This function will take an object, and flatten the properties using their full path into a single object with one layer of properties.
        You can use this to flatten XML, JSON, and other arbitrary objects.
        This can simplify initial exploration and discovery of data returned by APIs, interfaces, and other technologies.
        NOTE:
            Use tools like Get-Member, Select-Object, and Show-Object to further explore objects.
            This function does not handle certain data types well.  It was original designed to expand XML and JSON.
    .PARAMETER InputObject
        Object to flatten
    .PARAMETER Exclude
        Exclude any nodes in this list.  Accepts wildcards.
        Example:
            -Exclude price, title
    .PARAMETER ExcludeDefault
        Exclude default properties for sub objects.  True by default.
        This simplifies views of many objects (e.g. XML) but may exclude data for others (e.g. if flattening a process, ProcessThread properties will be excluded)
    .PARAMETER Include
        Include only leaves in this list.  Accepts wildcards.
        Example:
            -Include Author, Title
    .PARAMETER Value
        Include only leaves with values like these arguments.  Accepts wildcards.
    .PARAMETER MaxDepth
        Stop recursion at this depth.
    .INPUTS
        Any object
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        #Pull unanswered PowerShell questions from StackExchange, Flatten the data to date a feel for the schema
        Invoke-RestMethod "https://api.stackexchange.com/2.0/questions/unanswered?order=desc&sort=activity&tagged=powershell&pagesize=10&site=stackoverflow" |
            ConvertTo-FlatObject -Include Title, Link, View_Count
            $object.items[0].owner.link : http://stackoverflow.com/users/1946412/julealgon
            $object.items[0].view_count : 7
            $object.items[0].link       : http://stackoverflow.com/questions/26910789/is-it-possible-to-reuse-a-param-block-across-multiple-functions
            $object.items[0].title      : Is it possible to reuse a &#39;param&#39; block across multiple functions?
            $object.items[1].owner.link : http://stackoverflow.com/users/4248278/nitin-tyagi
            $object.items[1].view_count : 8
            $object.items[1].link       : http://stackoverflow.com/questions/26909879/use-powershell-to-retreive-activated-features-for-sharepoint-2010
            $object.items[1].title      : Use powershell to retreive Activated features for sharepoint 2010
            ...
    .EXAMPLE
        #Set up some XML to work with
        $object = [xml]'
            <catalog>
               <book id="bk101">
                  <author>Gambardella, Matthew</author>
                  <title>XML Developers Guide</title>
                  <genre>Computer</genre>
                  <price>44.95</price>
               </book>
               <book id="bk102">
                  <author>Ralls, Kim</author>
                  <title>Midnight Rain</title>
                  <genre>Fantasy</genre>
                  <price>5.95</price>
               </book>
            </catalog>'
        #Call the flatten command against this XML
            ConvertTo-FlatObject $object -Include Author, Title, Price
            #Result is a flattened object with the full path to the node, using $object as the root.
            #Only leaf properties we specified are included (author,title,price)
                $object.catalog.book[0].author : Gambardella, Matthew
                $object.catalog.book[0].title  : XML Developers Guide
                $object.catalog.book[0].price  : 44.95
                $object.catalog.book[1].author : Ralls, Kim
                $object.catalog.book[1].title  : Midnight Rain
                $object.catalog.book[1].price  : 5.95
        #Invoking the property names should return their data if the orginal object is in $object:
            $object.catalog.book[1].price
                5.95
            $object.catalog.book[0].title
                XML Developers Guide
    .EXAMPLE
        #Set up some XML to work with
            [xml]'<catalog>
               <book id="bk101">
                  <author>Gambardella, Matthew</author>
                  <title>XML Developers Guide</title>
                  <genre>Computer</genre>
                  <price>44.95</price>
               </book>
               <book id="bk102">
                  <author>Ralls, Kim</author>
                  <title>Midnight Rain</title>
                  <genre>Fantasy</genre>
                  <price>5.95</price>
               </book>
            </catalog>' |
                ConvertTo-FlatObject -exclude price, title, id
        Result is a flattened object with the full path to the node, using XML as the root.  Price and title are excluded.
            $Object.catalog                : catalog
            $Object.catalog.book           : {book, book}
            $object.catalog.book[0].author : Gambardella, Matthew
            $object.catalog.book[0].genre  : Computer
            $object.catalog.book[1].author : Ralls, Kim
            $object.catalog.book[1].genre  : Fantasy
    .EXAMPLE
        #Set up some XML to work with
            [xml]'<catalog>
               <book id="bk101">
                  <author>Gambardella, Matthew</author>
                  <title>XML Developers Guide</title>
                  <genre>Computer</genre>
                  <price>44.95</price>
               </book>
               <book id="bk102">
                  <author>Ralls, Kim</author>
                  <title>Midnight Rain</title>
                  <genre>Fantasy</genre>
                  <price>5.95</price>
               </book>
            </catalog>' |
                ConvertTo-FlatObject -Value XML*, Fantasy
        Result is a flattened object filtered by leaves that matched XML* or Fantasy
            $Object.catalog.book[0].title : XML Developers Guide
            $Object.catalog.book[1].genre : Fantasy
    .EXAMPLE
        #Get a single process with all props, flatten this object.  Don't exclude default properties
        Get-Process | select -first 1 -skip 10 -Property * | ConvertTo-FlatObject -ExcludeDefault $false
        #NOTE - There will likely be bugs for certain complex objects like this.
                For example, $Object.StartInfo.Verbs.SyncRoot.SyncRoot... will loop until we hit MaxDepth. (Note: SyncRoot is now addressed individually)
    .NOTES
        I have trouble with algorithms.  If you have a better way to handle this, please let me know!
    .FUNCTIONALITY
        General Command
    #>
    [cmdletbinding()]
    param(

        [parameter( Mandatory = $True,
                    ValueFromPipeline = $True)]
        [PSObject[]]$InputObject,

        [string[]]$Exclude = "",

        [bool]$ExcludeDefault = $True,

        [string[]]$Include = $null,

        [string[]]$Value = $null,

        [int]$MaxDepth = 10
    )
    Begin
    {
        #region FUNCTIONS

            #Before adding a property, verify that it matches a Like comparison to strings in $Include...
            Function IsIn-Include {
                param($prop)
                if(-not $Include) {$True}
                else {
                    foreach($Inc in $Include)
                    {
                        if($Prop -like $Inc)
                        {
                            $True
                        }
                    }
                }
            }

            #Before adding a value, verify that it matches a Like comparison to strings in $Value...
            Function IsIn-Value {
                param($val)
                if(-not $Value) {$True}
                else {
                    foreach($string in $Value)
                    {
                        if($val -like $string)
                        {
                            $True
                        }
                    }
                }
            }

            Function Get-Exclude {
                [cmdletbinding()]
                param($obj)

                #Exclude default props if specified, and anything the user specified.  Thanks to Jaykul for the hint on [type]!
                    if($ExcludeDefault)
                    {
                        Try
                        {
                            $DefaultTypeProps = @( $obj.gettype().GetProperties() | Select -ExpandProperty Name -ErrorAction Stop )
                            if($DefaultTypeProps.count -gt 0)
                            {
                                Write-Verbose "Excluding default properties for $($obj.gettype().Fullname):`n$($DefaultTypeProps | Out-String)"
                            }
                        }
                        Catch
                        {
                            Write-Verbose "Failed to extract properties from $($obj.gettype().Fullname): $_"
                            $DefaultTypeProps = @()
                        }
                    }

                    @( $Exclude + $DefaultTypeProps ) | Select -Unique
            }

            #Function to recurse the Object, add properties to object
            Function Recurse-Object {
                [cmdletbinding()]
                param(
                    $Object,
                    [string[]]$path = '$Object',
                    [psobject]$Output,
                    $depth = 0
                )

                # Handle initial call
                    Write-Verbose "Working in path $Path at depth $depth"
                    Write-Debug "Recurse Object called with PSBoundParameters:`n$($PSBoundParameters | Out-String)"
                    $Depth++

                #Exclude default props if specified, and anything the user specified.
                    $ExcludeProps = @( Get-Exclude $object )

                #Get the children we care about, and their names
                    $Children = $object.psobject.properties | Where {$ExcludeProps -notcontains $_.Name }
                    Write-Debug "Working on properties:`n$($Children | select -ExpandProperty Name | Out-String)"

                #Loop through the children properties.
                foreach($Child in @($Children))
                {
                    $ChildName = $Child.Name
                    $ChildValue = $Child.Value

                    Write-Debug "Working on property $ChildName with value $($ChildValue | Out-String)"
                    # Handle special characters...
                        if($ChildName -match '[^a-zA-Z0-9_]')
                        {
                            $FriendlyChildName = "'$ChildName'"
                        }
                        else
                        {
                            $FriendlyChildName = $ChildName
                        }

                    #Add the property.
                        if((IsIn-Include $ChildName) -and (IsIn-Value $ChildValue) -and $Depth -le $MaxDepth)
                        {
                            $ThisPath = @( $Path + $FriendlyChildName ) -join "."
                            $Output | Add-Member -MemberType NoteProperty -Name $ThisPath -Value $ChildValue
                            Write-Verbose "Adding member '$ThisPath'"
                        }

                    #Handle null...
                        if($ChildValue -eq $null)
                        {
                            Write-Verbose "Skipping NULL $ChildName"
                            continue
                        }

                    #Handle evil looping.  Will likely need to expand this.  Any thoughts on a better approach?
                        if(
                            (
                                $ChildValue.GetType() -eq $Object.GetType() -and
                                $ChildValue -is [datetime]
                            ) -or
                            (
                                $ChildName -eq "SyncRoot" -and
                                -not $ChildValue
                            )
                        )
                        {
                            Write-Verbose "Skipping $ChildName with type $($ChildValue.GetType().fullname)"
                            continue
                        }

                    #Check for arrays
                        $IsArray = @($ChildValue).count -gt 1
                        $count = 0

                    #Set up the path to this node and the data...
                        $CurrentPath = @( $Path + $FriendlyChildName ) -join "."

                    #Exclude default props if specified, and anything the user specified.
                        $ExcludeProps = @( Get-Exclude $ChildValue )

                    #Get the children's children we care about, and their names.  Also look for signs of a hashtable like type
                        $ChildrensChildren = $ChildValue.psobject.properties | Where {$ExcludeProps -notcontains $_.Name }
                        $HashKeys = if($ChildValue.Keys -notlike $null -and $ChildValue.Values)
                        {
                            $ChildValue.Keys
                        }
                        else
                        {
                            $null
                        }
                        Write-Debug "Found children's children $($ChildrensChildren | select -ExpandProperty Name | Out-String)"

                    #If we aren't at max depth or a leaf...
                    if(
                        (@($ChildrensChildren).count -ne 0 -or $HashKeys) -and
                        $Depth -lt $MaxDepth
                    )
                    {
                        #This handles hashtables.  But it won't recurse...
                            if($HashKeys)
                            {
                                Write-Verbose "Working on hashtable $CurrentPath"
                                foreach($key in $HashKeys)
                                {
                                    Write-Verbose "Adding value from hashtable $CurrentPath['$key']"
                                    $Output | Add-Member -MemberType NoteProperty -name "$CurrentPath['$key']" -value $ChildValue["$key"]
                                    $Output = Recurse-Object -Object $ChildValue["$key"] -Path "$CurrentPath['$key']" -Output $Output -depth $depth
                                }
                            }
                        #Sub children?  Recurse!
                            else
                            {
                                if($IsArray)
                                {
                                    foreach($item in @($ChildValue))
                                    {
                                        Write-Verbose "Recursing through array node '$CurrentPath'"
                                        $Output = Recurse-Object -Object $item -Path "$CurrentPath[$count]" -Output $Output -depth $depth
                                        $Count++
                                    }
                                }
                                else
                                {
                                    Write-Verbose "Recursing through node '$CurrentPath'"
                                    $Output = Recurse-Object -Object $ChildValue -Path $CurrentPath -Output $Output -depth $depth
                                }
                            }
                        }
                    }

                $Output
            }

        #endregion FUNCTIONS
    }
    Process
    {
        Foreach($Object in $InputObject)
        {
            #Flatten the XML and write it to the pipeline
                Recurse-Object -Object $Object -Output $( New-Object -TypeName PSObject )
        }
    }
}

function Show-Object-Detail
{
    <#
    .SYNOPSIS
        Decorate an object with
            - A TypeName
            - New properties
            - Default parameters
    .DESCRIPTION
        Helper function to decorate an object with
            - A TypeName
            - New properties
            - Default parameters 
    .PARAMETER InputObject
        Object to decorate. Accepts pipeline input.
    .PARAMETER TypeName
        Typename to insert.
        
        This will show up when you use Get-Member against the resulting object.
        
    .PARAMETER PropertyToAdd
        Add these noteproperties.
        
        Format is a hashtable with Key (Property Name) = Value (Property Value).
        Example to add a One and Date property:
            -PropertyToAdd @{
                One = 1
                Date = (Get-Date)
            }
    .PARAMETER DefaultProperties
        Change the default properties that show up
    .PARAMETER Passthru
        Whether to pass the resulting object on. Defaults to true
    .EXAMPLE
        #
        # Create an object to work with
        $Object = [PSCustomObject]@{
            First = 'Cookie'
            Last = 'Monster'
            Account = 'CMonster'
        }
        #Add a type name and a random property
        Add-ObjectDetail -InputObject $Object -TypeName 'ApplicationX.Account' -PropertyToAdd @{ AnotherProperty = 5 }
            # First  Last    Account  AnotherProperty
            # -----  ----    -------  ---------------
            # Cookie Monster CMonster               5
        #Verify that get-member shows us the right type
        $Object | Get-Member
            # TypeName: ApplicationX.Account ...
    .EXAMPLE
        #
        # Create an object to work with
        $Object = [PSCustomObject]@{
            First = 'Cookie'
            Last = 'Monster'
            Account = 'CMonster'
        }
        #Add a random property, set a default property set so we only see two props by default
        Add-ObjectDetail -InputObject $Object -PropertyToAdd @{ AnotherProperty = 5 } -DefaultProperties Account, AnotherProperty
            # Account  AnotherProperty
            # -------  ---------------
            # CMonster               5
        #Verify that the other properties are around
        $Object | Select -Property *
            # First  Last    Account  AnotherProperty
            # -----  ----    -------  ---------------
            # Cookie Monster CMonster               5
    .NOTES
        This breaks the 'do one thing' rule from certain perspectives...
        The goal is to decorate an object all in one shot
   
        This abstraction simplifies decorating an object, with a slight trade-off in performance. For example:
        10,000 objects, add a property and typename:
            Add-ObjectDetail:                        ~4.6 seconds
            Add-Member + PSObject.TypeNames.Insert:  ~3 seconds
        Initial code borrowed from Shay Levy:
        http://blogs.microsoft.co.il/scriptfanatic/2012/04/13/custom-objects-default-display-in-powershell-30/
        
    .LINK
        http://ramblingcookiemonster.github.io/Decorating-Objects/
    .FUNCTIONALITY
        PowerShell Language
    #>
    [CmdletBinding()] 
    param(
           [Parameter( Mandatory = $true,
                       Position=0,
                       ValueFromPipeline=$true )]
           [ValidateNotNullOrEmpty()]
           [psobject[]]$InputObject,

           [Parameter( Mandatory = $false,
                       Position=1)]
           [string]$TypeName,

           [Parameter( Mandatory = $false,
                       Position=2)]    
           [System.Collections.Hashtable]$PropertyToAdd,

           [Parameter( Mandatory = $false,
                       Position=3)]
           [ValidateNotNullOrEmpty()]
           [Alias('dp')]
           [System.String[]]$DefaultProperties,

           [boolean]$Passthru = $True
    )
    
    Begin
    {
        if($PSBoundParameters.ContainsKey('DefaultProperties'))
        {
            # define a subset of properties
            $ddps = New-Object System.Management.Automation.PSPropertySet DefaultDisplayPropertySet,$DefaultProperties
            $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]$ddps
        }
    }
    Process
    {
        foreach($Object in $InputObject)
        {
            switch ($PSBoundParameters.Keys)
            {
                'PropertyToAdd'
                {
                    foreach($Key in $PropertyToAdd.Keys)
                    {
                        #Add some noteproperties. Slightly faster than Add-Member.
                        $Object.PSObject.Properties.Add( ( New-Object System.Management.Automation.PSNoteProperty($Key, $PropertyToAdd[$Key]) ) )  
                    }
                }
                'TypeName'
                {
                    #Add specified type
                    [void]$Object.PSObject.TypeNames.Insert(0,$TypeName)
                }
                'DefaultProperties'
                {
                    # Attach default display property set
                    Add-Member -InputObject $Object -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers
                }
            }
            if($Passthru)
            {
                $Object
            }
        }
    }
}

function Show-Object-List
{
    #############################################################################
    ##
    ## Show-Object
    ##
    ## From Windows PowerShell Cookbook (O'Reilly)
    ## by Lee Holmes (http://www.leeholmes.com/guide)
    ##
    ##############################################################################
    
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
    
    param(
        ## The object to examine
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )
    
    Set-StrictMode -Version 3
    
    Add-Type -Assembly System.Windows.Forms
    
    ## Figure out the variable name to use when displaying the
    ## object navigation syntax. To do this, we look through all
    ## of the variables for the one with the same object identifier.
    $rootVariableName = dir variable:\* -Exclude InputObject,Args |
        Where-Object {
            $_.Value -and
            ($_.Value.GetType() -eq $InputObject.GetType()) -and
            ($_.Value.GetHashCode() -eq $InputObject.GetHashCode())
    }
    
    ## If we got multiple, pick the first
    $rootVariableName = $rootVariableName| % Name | Select -First 1
    
    ## If we didn't find one, use a default name
    if(-not $rootVariableName)
    {
        $rootVariableName = "InputObject"
    }
    
    ## A function to add an object to the display tree
    function PopulateNode($node, $object)
    {
        ## If we've been asked to add a NULL object, just return
        if(-not $object) { return }
    
        ## If the object is a collection, then we need to add multiple
        ## children to the node
        if([System.Management.Automation.LanguagePrimitives]::GetEnumerator($object))
        {
            ## Some very rare collections don't support indexing (i.e.: $foo[0]).
            ## In this situation, PowerShell returns the parent object back when you
            ## try to access the [0] property.
            $isOnlyEnumerable = $object.GetHashCode() -eq $object[0].GetHashCode()
    
            ## Go through all the items
            $count = 0
            foreach($childObjectValue in $object)
            {
                ## Create the new node to add, with the node text of the item and
                ## value, along with its type
             $newChildNode = New-Object Windows.Forms.TreeNode
                $newChildNode.Text = "$($node.Name)[$count] = $childObjectValue"
                $newChildNode.ToolTipText = $childObjectValue.GetType()
                   
                ## Use the node name to keep track of the actual property name
                ## and syntax to access that property.
                ## If we can't use the index operator to access children, add
                ## a special tag that we'll handle specially when displaying
                ## the node names.
                if($isOnlyEnumerable)
                {
                    $newChildNode.Name = "@"
                }
    
                $newChildNode.Name += "[$count]"
             $null = $node.Nodes.Add($newChildNode)               
    
                ## If this node has children or properties, add a placeholder
                ## node underneath so that the node shows a '+' sign to be
                ## expanded.
                AddPlaceholderIfRequired $newChildNode $childObjectValue
    
                $count++
            }
        }
        else
        {
            ## If the item was not a collection, then go through its
            ## properties
            foreach($child in $object.PSObject.Properties)
            {
                ## Figure out the value of the property, along with
                ## its type.
             $childObject = $child.Value
                $childObjectType = $null
                if($childObject)
                {
                    $childObjectType = $childObject.GetType()
                }
    
                ## Create the new node to add, with the node text of the item and
                ## value, along with its type
             $childNode = New-Object Windows.Forms.TreeNode
                $childNode.Text = $child.Name + " = $childObject"
                $childNode.ToolTipText = $childObjectType
                if([System.Management.Automation.LanguagePrimitives]::GetEnumerator($childObject))
                {
                    $childNode.ToolTipText += "[]"
                }
                
                $childNode.Name = $child.Name
             $null = $node.Nodes.Add($childNode)
    
                ## If this node has children or properties, add a placeholder
                ## node underneath so that the node shows a '+' sign to be
                ## expanded.
                AddPlaceholderIfRequired $childNode $childObject
            }
        }
    }
    
    ## A function to add a placeholder if required to a node.
    ## If there are any properties or children for this object, make a temporary
    ## node with the text "..." so that the node shows a '+' sign to be
    ## expanded.
    function AddPlaceholderIfRequired($node, $object)
    {
        if(-not $object) { return }
    
        if([System.Management.Automation.LanguagePrimitives]::GetEnumerator($object) -or
            @($object.PSObject.Properties))
        {
            $null = $node.Nodes.Add( (New-Object Windows.Forms.TreeNode "...") )
        }
    }
    
    ## A function invoked when a node is selected.
    function OnAfterSelect
    {
        param($Sender, $TreeViewEventArgs)
    
        ## Determine the selected node
        $nodeSelected = $Sender.SelectedNode
    
        ## Walk through its parents, creating the virtual
        ## PowerShell syntax to access this property.
        $nodePath = GetPathForNode $nodeSelected
    
        ## Now, invoke that PowerShell syntax to retrieve
        ## the value of the property.
        $resultObject = Invoke-Expression $nodePath
        $outputPane.Text = $nodePath
    
        ## If we got some output, put the object's member
        ## information in the text box.
        if($resultObject)
        {
            $members = Get-Member -InputObject $resultObject | Out-String       
            $outputPane.Text += "`n" + $members
        }
    }
    
    ## A function invoked when the user is about to expand a node
    function OnBeforeExpand
    {
        param($Sender, $TreeViewCancelEventArgs)
    
        ## Determine the selected node
        $selectedNode = $TreeViewCancelEventArgs.Node
    
        ## If it has a child node that is the placeholder, clear
        ## the placehoder node.
        if($selectedNode.FirstNode -and
            ($selectedNode.FirstNode.Text -eq "..."))
        {
            $selectedNode.Nodes.Clear()
        }
        else
        {
            return
        }
    
        ## Walk through its parents, creating the virtual
        ## PowerShell syntax to access this property.
        $nodePath = GetPathForNode $selectedNode 
    
        ## Now, invoke that PowerShell syntax to retrieve
        ## the value of the property.
        Invoke-Expression "`$resultObject = $nodePath"
    
        ## And populate the node with the result object.
        PopulateNode $selectedNode $resultObject
    }
    
    ## A function to handle key presses on the tree view.
    ## In this case, we capture ^C to copy the path of
    ## the object property that we're currently viewing.
    function OnTreeViewKeyPress
    {
        param($Sender, $KeyPressEventArgs)
    
        ## [Char] 3 = Control-C
        if($KeyPressEventArgs.KeyChar -eq 3)
        {
            $KeyPressEventArgs.Handled = $true
    
            ## Get the object path, and set it on the clipboard
            $node = $Sender.SelectedNode
            $nodePath = GetPathForNode $node
            [System.Windows.Forms.Clipboard]::SetText($nodePath)
    
            $form.Close()
        }
        elseif([System.Windows.Forms.Control]::ModifierKeys -eq "Control")
        {
            if($KeyPressEventArgs.KeyChar -eq '+')
            {
                $SCRIPT:currentFontSize++
                UpdateFonts $SCRIPT:currentFontSize
            
                $KeyPressEventArgs.Handled = $true
            }
            elseif($KeyPressEventArgs.KeyChar -eq '-')
            {
                $SCRIPT:currentFontSize--
                if($SCRIPT:currentFontSize -lt 1) { $SCRIPT:currentFontSize = 1 }
                UpdateFonts $SCRIPT:currentFontSize
            
                $KeyPressEventArgs.Handled = $true
            }
        }
    }

    ## A function to handle key presses on the form.
    ## In this case, we handle Ctrl-Plus and Ctrl-Minus
    ## to adjust font size.
    function OnKeyUp
    {
        param($Sender, $KeyUpEventArgs)

        if([System.Windows.Forms.Control]::ModifierKeys -eq "Control")
        {
            if($KeyUpEventArgs.KeyCode -in 'Add','OemPlus')
            {
                $SCRIPT:currentFontSize++
                UpdateFonts $SCRIPT:currentFontSize
            
                $KeyUpEventArgs.Handled = $true
            }
            elseif($KeyUpEventArgs.KeyCode -in 'Subtract','OemMinus')
            {
                $SCRIPT:currentFontSize--
                if($SCRIPT:currentFontSize -lt 1) { $SCRIPT:currentFontSize = 1 }
                UpdateFonts $SCRIPT:currentFontSize
            
                $KeyUpEventArgs.Handled = $true
            }
            elseif($KeyUpEventArgs.KeyCode -eq 'D0')
            {
                $SCRIPT:currentFontSize = 12
                UpdateFonts $SCRIPT:currentFontSize
            
                $KeyUpEventArgs.Handled = $true
            }
        }
    }

    ## A function to handle mouse wheel scrolling.
    ## In this case, we translate Ctrl-Wheel to zoom.
    function OnMouseWheel
    {
        param($Sender, $MouseEventArgs)
    
        if(
            ([System.Windows.Forms.Control]::ModifierKeys -eq "Control") -and
            ($MouseEventArgs.Delta -ne 0))
        {
            $SCRIPT:currentFontSize += ($MouseEventArgs.Delta / 120)
            if($SCRIPT:currentFontSize -lt 1) { $SCRIPT:currentFontSize = 1 }

            UpdateFonts $SCRIPT:currentFontSize
            $MouseEventArgs.Handled = $true
        }
    }
    
    ## A function to walk through the parents of a node,
    ## creating virtual PowerShell syntax to access this property.
    function GetPathForNode
    {
        param($Node)
    
        $nodeElements = @()
    
        ## Go through all the parents, adding them so that
        ## $nodeElements is in order.
        while($Node)
        {
            $nodeElements = ,$Node + $nodeElements
            $Node = $Node.Parent
        }
    
        ## Now go through the node elements
        $nodePath = ""
        foreach($Node in $nodeElements)
        {
            $nodeName = $Node.Name
    
            ## If it was a node that PowerShell is able to enumerate
            ## (but not index), wrap it in the array cast operator.
if($nodeName.StartsWith('@'))
            {
                $nodeName = $nodeName.Substring(1)
$nodePath = "@(" + $nodePath + ")"
            }
            elseif($nodeName.StartsWith('['))
            {
                ## If it's a child index, we don't need to
                ## add the dot for property access
            }
            elseif($nodePath)
            {
                ## Otherwise, we're accessing a property. Add a dot.
                $nodePath += "."
            }
    
            ## Append the node name to the path
$tempNodePath = $nodePath + $nodeName
if($nodeName -notmatch '^[$\[\]a-zA-Z0-9]+$')
{
$nodePath += "'" + $nodeName + "'"
}
else
{
$nodePath = $tempNodePath
}
        }
    
        ## And return the result
        $nodePath
    }

    function UpdateFonts
    {
        param($fontSize)

        $treeView.Font = New-Object System.Drawing.Font "Consolas",$fontSize
        $outputPane.Font = New-Object System.Drawing.Font "Consolas",$fontSize
    }
    
    $SCRIPT:currentFontSize = 12

    ## Create the TreeView, which will hold our object navigation
    ## area.
    $treeView = New-Object Windows.Forms.TreeView
    $treeView.Dock = "Top"
    $treeView.Height = 500
    $treeView.PathSeparator = "."
    $treeView.ShowNodeToolTips = $true
    $treeView.Add_AfterSelect( { OnAfterSelect @args } )
    $treeView.Add_BeforeExpand( { OnBeforeExpand @args } )
    $treeView.Add_KeyPress( { OnTreeViewKeyPress @args } )
    
    ## Create the output pane, which will hold our object
    ## member information.
    $outputPane = New-Object System.Windows.Forms.TextBox
    $outputPane.Multiline = $true
    $outputPane.WordWrap = $false
    $outputPane.ScrollBars = "Both"
    $outputPane.Dock = "Fill"

    ## Create the root node, which represents the object
    ## we are trying to show.
    $root = New-Object Windows.Forms.TreeNode
    $root.ToolTipText = $InputObject.GetType()
    $root.Text = $InputObject
    $root.Name = '$' + $rootVariableName
    $root.Expand()
    $null = $treeView.Nodes.Add($root)

    UpdateFonts $currentFontSize
    
    ## And populate the initial information into the tree
    ## view.
    PopulateNode $root $InputObject
    
    ## Finally, create the main form and show it.
    $form = New-Object Windows.Forms.Form
    $form.Text = "Browsing " + $root.Text
    $form.Width = 1000
    $form.Height = 800
    $form.Controls.Add($outputPane)
    $form.Controls.Add($treeView)
    $form.Add_MouseWheel( { OnMouseWheel @args } )
    $treeView.Add_KeyUp( { OnKeyUp @args } )
    $treeView.Select()
    $null = $form.ShowDialog()
    $form.Dispose()
}

function Show-Object-Tree{
	
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
			
param(
    ## The object to examine
    [Parameter(ValueFromPipeline = $true)]
    $InputObject
)

#custom controls for treeview... found it on MSDN a while ago, lost link :-/
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
add-type @"
using System;
using System.Windows.Controls;
using System.Windows;
using System.Windows.Data;
using System.Globalization;


namespace _treeListView
{
    public class TreeListView : TreeView
    {
        protected override DependencyObject GetContainerForItemOverride()
        {
            return new TreeListViewItem();
        }

        protected override bool IsItemItsOwnContainerOverride(object item)
        {
            return item is TreeListViewItem;
        }
    }

    public class TreeListViewItem : TreeViewItem
    {
        private int _level = -1;
        public int Level
        {
            get
            {
                if (_level != -1) return _level;
                var parent = ItemsControl.ItemsControlFromItemContainer(this) as TreeListViewItem;
                _level = (parent != null) ? parent.Level + 1 : 0;
                return _level;
            }
        }

        public TreeListViewItem(object header)
        {
            Header = header;
        }

        public TreeListViewItem(){}

        protected override DependencyObject GetContainerForItemOverride()
        {
            return new TreeListViewItem();
        }

        protected override bool IsItemItsOwnContainerOverride(object item)
        {
            return item is TreeListViewItem;
        }
    }

    public class LevelToIndentConverter : IValueConverter
    {
        private const double c_IndentSize = 19.0;
        public object Convert(object o, Type type, object parameter,CultureInfo culture)
        {
            return new Thickness((int)o * c_IndentSize, 0, 0, 0);
        }

        public object ConvertBack(object o, Type type, object parameter,CultureInfo culture)
        {
            throw new NotSupportedException();
        }
    }

}
"@ -ReferencedAssemblies presentationFramework,PresentationCore,WindowsBase,System.Xaml -ErrorAction SilentlyContinue
## form layout
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
	    xmlns:s='clr-namespace:System;assembly=mscorlib' 
	    xmlns:l='clr-namespace:_treeListView;assembly=$([_treeListView.LevelToIndentConverter].Assembly)' 
		Title="TreeListView" Width="640" Height="480">
    <Window.Resources>
    <Style x:Key="ExpandCollapseToggleStyle"
           TargetType="{x:Type ToggleButton}">
            <Setter Property="Focusable" Value="False"/>
            <Setter Property="Width" Value="19"/>
            <Setter Property="Height" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ToggleButton}">
                        <Border Width="19" Height="13" Background="Transparent">
                            <Border Width="9" Height="9" BorderThickness="1" BorderBrush="#FF7898B5" CornerRadius="1" SnapsToDevicePixels="true">
                                <Border.Background>
								<LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                        <LinearGradientBrush.GradientStops>
                                            <GradientStop Color="White" Offset=".2"/>
                                            <GradientStop Color="#FFC0B7A6" Offset="1"/>
                                        </LinearGradientBrush.GradientStops>
                                    </LinearGradientBrush>
                                </Border.Background>
                                <Path x:Name="ExpandPath" Margin="1,1,1,1" Fill="Black" 
                                      Data="M 0 2 L 0 3 L 2 3 L 2 5 L 3 5 L 3 3 L 5 3 L 5 2 L 3 2 L 3 0 L 2 0 L 2 2 Z"/>
                            </Border>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter Property="Data" TargetName="ExpandPath" Value="M 0 2 L 0 3 L 5 3 L 5 2 Z"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <l:LevelToIndentConverter x:Key="LevelToIndentConverter"/>

        <DataTemplate x:Key="CellTemplate_Name">
            <DockPanel>
                <ToggleButton x:Name="Expander" 
                      Style="{StaticResource ExpandCollapseToggleStyle}" 
                      Margin="{Binding Level, Converter={StaticResource LevelToIndentConverter},
                             RelativeSource={RelativeSource AncestorType={x:Type l:TreeListViewItem}}}"
                      IsChecked="{Binding Path=IsExpanded, RelativeSource=
                    {RelativeSource AncestorType={x:Type l:TreeListViewItem}}}"
                      ClickMode="Press"/>
                <TextBlock Text="{Binding Name}"/>
            </DockPanel>
            <DataTemplate.Triggers>
                <DataTrigger Binding="{Binding Path=HasItems,RelativeSource={RelativeSource AncestorType={x:Type l:TreeListViewItem}}}" Value="False">
                    <Setter TargetName="Expander" Property="Visibility" Value="Hidden"/>
                </DataTrigger>
            </DataTemplate.Triggers>
        </DataTemplate>

        <GridViewColumnCollection x:Key="gvcc">
            <GridViewColumn Header="Name" CellTemplate="{StaticResource CellTemplate_Name}" />
            <GridViewColumn Header="MemberType" DisplayMemberBinding="{Binding MemberType}" />
            <GridViewColumn Header="Definition" DisplayMemberBinding="{Binding Definition}" />
            <GridViewColumn Header="Value" DisplayMemberBinding="{Binding Value}" />
        </GridViewColumnCollection>

        <Style TargetType="{x:Type l:TreeListViewItem}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type l:TreeListViewItem}">
                        <StackPanel>
                            <Border Name="Bd"
                      Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}"
                      Padding="{TemplateBinding Padding}">
                                <GridViewRowPresenter x:Name="PART_Header" 
                                      Content="{TemplateBinding Header}" 
                                      Columns="{StaticResource gvcc}" />
                            </Border>
                            <ItemsPresenter x:Name="ItemsHost" />
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsExpanded" Value="false">
                                <Setter TargetName="ItemsHost" Property="Visibility" Value="Collapsed"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="HasHeader" Value="false"/>
                                    <Condition Property="Width" Value="Auto"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="PART_Header" Property="MinWidth" Value="75"/>
                            </MultiTrigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="HasHeader" Value="false"/>
                                    <Condition Property="Height" Value="Auto"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="PART_Header" Property="MinHeight" Value="19"/>
                            </MultiTrigger>
                            <Trigger Property="IsSelected" Value="true">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource {x:Static SystemColors.HighlightBrushKey}}"/>
                                <Setter Property="Foreground" Value="{DynamicResource {x:Static SystemColors.HighlightTextBrushKey}}"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="IsSelected" Value="true"/>
                                    <Condition Property="IsSelectionActive" Value="false"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource  {x:Static SystemColors.ControlBrushKey}}"/>
                                <Setter Property="Foreground" Value="{DynamicResource {x:Static SystemColors.ControlTextBrushKey}}"/>
                            </MultiTrigger>
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter Property="Foreground" Value="{DynamicResource {x:Static SystemColors.GrayTextBrushKey}}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="{x:Type l:TreeListView}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type l:TreeListView}">
                        <Border BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                            <DockPanel>
                                <GridViewHeaderRowPresenter Columns="{StaticResource gvcc}" DockPanel.Dock="Top"/>
                                <ScrollViewer CanContentScroll="True">
                                    <Grid>
                                    <ItemsPresenter/>
                                    </Grid>
                                </ScrollViewer>
                            </DockPanel>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <l:TreeListView x:Name="Tlv"/>
</Window>

"@

$rootVariableName = dir variable:\* -Exclude InputObject,Args |
    Where-Object {
        $_.Value -and
        ($_.Value.GetType() -eq $InputObject.GetType()) -and
        ($_.Value.GetHashCode() -eq $InputObject.GetHashCode())
}

## If we got multiple, pick the first
$rootVariableName = $rootVariableName| % Name | Select -First 1

## If we didn't find one, use a default name
if(-not $rootVariableName)
{
    $rootVariableName = "InputObject"
}

## A function to add an object to the display tree
function PopulateNode($node, $object)
{
    ## If we've been asked to add a NULL object, just return
    if(-not $object) { return }

    ## If the object is a collection, then we need to add multiple
    ## children to the node
    if([System.Management.Automation.LanguagePrimitives]::GetEnumerator($object))
    {
        ## Some very rare collections don't support indexing (i.e.: $foo[0]).
        ## In this situation, PowerShell returns the parent object back when you
        ## try to access the [0] property.
        $isOnlyEnumerable = $object.GetHashCode() -eq $object[0].GetHashCode()

        ## Go through all the items
        $count = 0
        foreach($childObjectValue in $object)
        {
            ## Create the new node to add, with the node text of the item and
            ## value, along with its type
            $newChildNode = New-Object _treeListView.TreeListViewItem
            #make sure the string version of it isnt more than a single line.
            $showValue = if(($arr="$childObjectValue" -split "\n" | ?{$_}).count -gt 1)
            {
                "$($arr[0].trim()) ..."
            }
            else
            {
                "$childObjectValue"
            }
            $newChildNode.ToolTip = "$childObjectValue"

            $newChildNode.Header = [pscustomobject] @{
                Name=$childObjectValue.GetType().name
                Value="$showValue"
                Definition=$childObjectValue.gettype()
                MemberType="Collection"
            }
            
            ## Use the node name to keep track of the actual property name
            ## and syntax to access that property.
            ## If we can't use the index operator to access children, add
            ## a special tag that we'll handle specially when displaying
            ## the node names.
            if($isOnlyEnumerable)
            {
                $newChildNode.Tag = "@"
            }

            $newChildNode.Tag += "[$count]"
            $null = $node.Items.Add($newChildNode)               

            ## If this node has children or properties, add a placeholder
            ## node underneath so that the node shows a '+' sign to be
            ## expanded.
            AddPlaceholderIfRequired $newChildNode $childObjectValue

            $count++
        }
    }
    else
    {
        ## If the item was not a collection, then go through its
        ## properties
        $members = Get-Member -InputObject $object
        foreach($member in $members)
        {
            $childNode = New-Object _treeListView.TreeListViewItem
            
            $memberValue = if($member.MemberType -like "*Propert*")
            {
                
                $prop = $object.($member.Name)                
                if($prop)
                {
                    $prop
                    $childnode.ToolTip = $prop
                    if($prop.gettype().fullname | ?{($_ -split '\.').count -gt 2})
                    {
                        AddPlaceholderIfRequired $childNode $prop
                    }
                }
                else { '$null' }
            }
            elseif($member.MemberType -eq "Method")
            {
               $childNode.ToolTip = ($object.($member.name) | Out-String).trim()
            }

            $showValue = if(($arr="$memberValue" -split "\n"|?{$_}).count -gt 1)
            {
                "$($arr[0].trim()) ..."
            }
            else
            {
                "$memberValue"
            }
            

            $childNode.Header = [pscustomobject] @{
                Name=$member.name
                Value=$showValue
                Definition=$member.Definition
                MemberType=$member.MemberType
            }

            $childNode.Tag = $member.Name
            $null = $node.Items.Add($childNode)
        }
    }
}

## A function to add a placeholder if required to a node.
## If there are any properties or children for this object, make a temporary
## node with the text "..." so that the node shows a '+' sign to be
## expanded.
function AddPlaceholderIfRequired($node, $object)
{
    if(-not $object) { return }

    if([System.Management.Automation.LanguagePrimitives]::GetEnumerator($object) -or
        @($object.PSObject.Properties))
    {
        $null = $node.Items.Add( (New-Object _treeListView.TreeListViewItem ([pscustomobject]@{Name="..."}) ) )
    }
}

## A function invoked when a node is selected.
function OnSelect
{
    param($Sender, $TreeViewEventArgs)

    ## Determine the selected node
    $nodeSelected = $TreeViewEventArgs.source

    ## Walk through its parents, creating the virtual
    ## PowerShell syntax to access this property.
    $nodePath = GetPathForNode $nodeSelected

    ## Now, invoke that PowerShell syntax to retrieve
    ## the value of the property.
    $resultObject = Invoke-Expression $nodePath
    #$outputPane.Text = $nodePath

    ## If we got some output, put the object's member
    ## information in the text box.
    
    if($resultObject)
    {
        $members = Get-Member -InputObject $resultObject | Out-String       
        #$outputPane.Text += "`n" + $members
    }
}

## A function invoked when the user is about to expand a node
function OnExpand
{
    param($Sender, $TreeViewCancelEventArgs)
    ## Determine the selected node
    $selectedNode = $TreeViewCancelEventArgs.Source
    ## If it has a child node that is the placeholder, clear
    ## the placeholder node.
    if($selectedNode.items.Count -eq 1 -and
        ($selectedNode.Items[0].Header.Name-eq "..."))
    {
        $selectedNode.items.Clear()
    }
    else
    {
        return
    }

    ## Walk through its parents, creating the virtual
    ## PowerShell syntax to access this property.
    $nodePath = GetPathForNode $selectedNode 
    $global:nodepath= $nodePath
    ## Now, invoke that PowerShell syntax to retrieve
    ## the value of the property.
    Invoke-Expression "`$resultObject = $nodePath"

    ## And populate the node with the result object.
    PopulateNode $selectedNode $resultObject
}

## A function to handle keypresses on the form.
## In this case, we capture ^C to copy the path of
## the object property that we're currently viewing.
function OnKeyPress
{
    param($Sender, $KeyPressEventArgs)

    ## [Char] 3 = Control-C
    if($KeyPressEventArgs.KeyChar -eq 3)
    {
        $KeyPressEventArgs.Handled = $true

        ## Get the object path, and set it on the clipboard
        $node = $Sender.SelectedNode
        $nodePath = GetPathForNode $node
        [System.Windows.Forms.Clipboard]::SetText($nodePath)

        $form.Close()
    }
}

## A function to walk through the parents of a node,
## creating virtual PowerShell syntax to access this property.
function GetPathForNode
{
    param($Node)

    $nodeElements = @()

    ## Go through all the parents, adding them so that
    ## $nodeElements is in order.
    while($Node.Tag)
    {
        $nodeElements = ,$Node + $nodeElements
        $Node = $Node.Parent
    }

    ## Now go through the node elements
    $nodePath = ""
    foreach($Node in $nodeElements)
    {
        $nodeName = $Node.Tag 

        ## If it was a node that PowerShell is able to enumerate
        ## (but not index), wrap it in the array cast operator.
        if($nodeName.StartsWith('@'))
        {
            $nodeName = $nodeName.Substring(1)
            $nodePath = "@(" + $nodePath + ")"
        }
        elseif($nodeName.StartsWith('['))
        {
            ## If it's a child index, we don't need to
            ## add the dot for property access
        }
        elseif($nodePath)
        {
            ## Otherwise, we're accessing a property. Add a dot.
            $nodePath += "."
        }

        ## Append the node name to the path
        $nodePath += $nodeName
    }

    ## And return the result
    $nodePath
}


## Create the TreeView, which will hold our object navigation
## area.

$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$Form=[Windows.Markup.XamlReader]::Load( $reader )

$tlv = $Form.FindName('Tlv')


[System.Windows.RoutedEventHandler]$Script:Select = { OnSelect @args }
[System.Windows.RoutedEventHandler]$Script:Expand = { OnExpand @args }
[System.Windows.RoutedEventHandler]$Script:KeyPress = { OnKeyPress @args }
$tlv.AddHandler([_treeListView.TreeListViewItem]::SelectedEvent, $Script:Select)
$tlv.AddHandler([_treeListView.TreeListViewItem]::ExpandedEvent, $Script:Expand)
$tlv.AddHandler([_treeListView.TreeListViewItem]::KeyUpEvent, $Script:KeyPress)


## Create the root node, which represents the object
## we are trying to show.
$root = New-Object _treeListView.TreeListViewItem ([pscustomobject]@{
    Name=$InputObject.gettype().name
    Value="$InputObject"
    Definition=$InputObject.gettype().fullname})

#root.Header = "$InputObject : " + $InputObject.GetType()
$root.Tag = '$' + $rootVariableName
$root.ToolTip = "$InputObject"
$root.IsExpanded = $true

## And populate the initial information into the tree
## view.
PopulateNode $root $InputObject

$null = $tlv.Items.Add($root)
$null = $Form.ShowDialog()


}
