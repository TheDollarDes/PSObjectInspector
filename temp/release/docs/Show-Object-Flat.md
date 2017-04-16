---
external help file: PSObjectInspector-help.xml
online version: http://ramblingcookiemonster.github.io/Decorating-Objects/
schema: 2.0.0
---

# Show-Object-Flat

## SYNOPSIS
Flatten an object to simplify discovery of data

## SYNTAX

```
Show-Object-Flat [-InputObject] <PSObject[]> [[-Exclude] <String[]>] [[-ExcludeDefault] <Boolean>]
 [[-Include] <String[]>] [[-Value] <String[]>] [[-MaxDepth] <Int32>]
```

## DESCRIPTION
Flatten an object. 
This function will take an object, and flatten the properties using their full path into a single object with one layer of properties.
You can use this to flatten XML, JSON, and other arbitrary objects.
This can simplify initial exploration and discovery of data returned by APIs, interfaces, and other technologies.
NOTE:
    Use tools like Get-Member, Select-Object, and Show-Object to further explore objects.
    This function does not handle certain data types well. 
It was original designed to expand XML and JSON.

## EXAMPLES

### -------------------------- EXAMPLE 1 --------------------------
```
#Pull unanswered PowerShell questions from StackExchange, Flatten the data to date a feel for the schema
```

Invoke-RestMethod "https://api.stackexchange.com/2.0/questions/unanswered?order=desc&sort=activity&tagged=powershell&pagesize=10&site=stackoverflow" |
    ConvertTo-FlatObject -Include Title, Link, View_Count
    $object.items\[0\].owner.link : http://stackoverflow.com/users/1946412/julealgon
    $object.items\[0\].view_count : 7
    $object.items\[0\].link       : http://stackoverflow.com/questions/26910789/is-it-possible-to-reuse-a-param-block-across-multiple-functions
    $object.items\[0\].title      : Is it possible to reuse a &#39;param&#39; block across multiple functions?
    $object.items\[1\].owner.link : http://stackoverflow.com/users/4248278/nitin-tyagi
    $object.items\[1\].view_count : 8
    $object.items\[1\].link       : http://stackoverflow.com/questions/26909879/use-powershell-to-retreive-activated-features-for-sharepoint-2010
    $object.items\[1\].title      : Use powershell to retreive Activated features for sharepoint 2010
    ...

### -------------------------- EXAMPLE 2 --------------------------
```
#Set up some XML to work with
```

$object = \[xml\]'
    \<catalog\>
       \<book id="bk101"\>
          \<author\>Gambardella, Matthew\</author\>
          \<title\>XML Developers Guide\</title\>
          \<genre\>Computer\</genre\>
          \<price\>44.95\</price\>
       \</book\>
       \<book id="bk102"\>
          \<author\>Ralls, Kim\</author\>
          \<title\>Midnight Rain\</title\>
          \<genre\>Fantasy\</genre\>
          \<price\>5.95\</price\>
       \</book\>
    \</catalog\>'
#Call the flatten command against this XML
    ConvertTo-FlatObject $object -Include Author, Title, Price
    #Result is a flattened object with the full path to the node, using $object as the root.
    #Only leaf properties we specified are included (author,title,price)
        $object.catalog.book\[0\].author : Gambardella, Matthew
        $object.catalog.book\[0\].title  : XML Developers Guide
        $object.catalog.book\[0\].price  : 44.95
        $object.catalog.book\[1\].author : Ralls, Kim
        $object.catalog.book\[1\].title  : Midnight Rain
        $object.catalog.book\[1\].price  : 5.95
#Invoking the property names should return their data if the orginal object is in $object:
    $object.catalog.book\[1\].price
        5.95
    $object.catalog.book\[0\].title
        XML Developers Guide

### -------------------------- EXAMPLE 3 --------------------------
```
#Set up some XML to work with
```

\[xml\]'\<catalog\>
       \<book id="bk101"\>
          \<author\>Gambardella, Matthew\</author\>
          \<title\>XML Developers Guide\</title\>
          \<genre\>Computer\</genre\>
          \<price\>44.95\</price\>
       \</book\>
       \<book id="bk102"\>
          \<author\>Ralls, Kim\</author\>
          \<title\>Midnight Rain\</title\>
          \<genre\>Fantasy\</genre\>
          \<price\>5.95\</price\>
       \</book\>
    \</catalog\>' |
        ConvertTo-FlatObject -exclude price, title, id
Result is a flattened object with the full path to the node, using XML as the root. 
Price and title are excluded.
    $Object.catalog                : catalog
    $Object.catalog.book           : {book, book}
    $object.catalog.book\[0\].author : Gambardella, Matthew
    $object.catalog.book\[0\].genre  : Computer
    $object.catalog.book\[1\].author : Ralls, Kim
    $object.catalog.book\[1\].genre  : Fantasy

### -------------------------- EXAMPLE 4 --------------------------
```
#Set up some XML to work with
```

\[xml\]'\<catalog\>
       \<book id="bk101"\>
          \<author\>Gambardella, Matthew\</author\>
          \<title\>XML Developers Guide\</title\>
          \<genre\>Computer\</genre\>
          \<price\>44.95\</price\>
       \</book\>
       \<book id="bk102"\>
          \<author\>Ralls, Kim\</author\>
          \<title\>Midnight Rain\</title\>
          \<genre\>Fantasy\</genre\>
          \<price\>5.95\</price\>
       \</book\>
    \</catalog\>' |
        ConvertTo-FlatObject -Value XML*, Fantasy
Result is a flattened object filtered by leaves that matched XML* or Fantasy
    $Object.catalog.book\[0\].title : XML Developers Guide
    $Object.catalog.book\[1\].genre : Fantasy

### -------------------------- EXAMPLE 5 --------------------------
```
#Get a single process with all props, flatten this object.  Don't exclude default properties
```

Get-Process | select -first 1 -skip 10 -Property * | ConvertTo-FlatObject -ExcludeDefault $false
#NOTE - There will likely be bugs for certain complex objects like this.
        For example, $Object.StartInfo.Verbs.SyncRoot.SyncRoot...
will loop until we hit MaxDepth.
(Note: SyncRoot is now addressed individually)

## PARAMETERS

### -InputObject
Object to flatten

```yaml
Type: PSObject[]
Parameter Sets: (All)
Aliases: 

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Exclude
Exclude any nodes in this list. 
Accepts wildcards.
Example:
    -Exclude price, title

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: 

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeDefault
Exclude default properties for sub objects. 
True by default.
This simplifies views of many objects (e.g.
XML) but may exclude data for others (e.g.
if flattening a process, ProcessThread properties will be excluded)

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases: 

Required: False
Position: 3
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -Include
Include only leaves in this list. 
Accepts wildcards.
Example:
    -Include Author, Title

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: 

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Value
Include only leaves with values like these arguments. 
Accepts wildcards.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: 

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxDepth
Stop recursion at this depth.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases: 

Required: False
Position: 6
Default value: 10
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

### Any object

## OUTPUTS

### System.Management.Automation.PSCustomObject

## NOTES
I have trouble with algorithms. 
If you have a better way to handle this, please let me know!

## RELATED LINKS

