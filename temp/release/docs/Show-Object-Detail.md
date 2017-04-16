---
external help file: PSObjectInspector-help.xml
online version: http://ramblingcookiemonster.github.io/Decorating-Objects/
schema: 2.0.0
---

# Show-Object-Detail

## SYNOPSIS
Decorate an object with
    - A TypeName
    - New properties
    - Default parameters

## SYNTAX

```
Show-Object-Detail [-InputObject] <PSObject[]> [[-TypeName] <String>] [[-PropertyToAdd] <Hashtable>]
 [[-DefaultProperties] <String[]>] [-Passthru <Boolean>]
```

## DESCRIPTION
Helper function to decorate an object with
    - A TypeName
    - New properties
    - Default parameters

## EXAMPLES

### -------------------------- EXAMPLE 1 --------------------------
```
#
```

# Create an object to work with
$Object = \[PSCustomObject\]@{
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

### -------------------------- EXAMPLE 2 --------------------------
```
#
```

# Create an object to work with
$Object = \[PSCustomObject\]@{
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

## PARAMETERS

### -InputObject
Object to decorate.
Accepts pipeline input.

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

### -TypeName
Typename to insert.

This will show up when you use Get-Member against the resulting object.

```yaml
Type: String
Parameter Sets: (All)
Aliases: 

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PropertyToAdd
Add these noteproperties.

Format is a hashtable with Key (Property Name) = Value (Property Value).
Example to add a One and Date property:
    -PropertyToAdd @{
        One = 1
        Date = (Get-Date)
    }

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases: 

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DefaultProperties
Change the default properties that show up

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: dp

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Passthru
Whether to pass the resulting object on.
Defaults to true

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases: 

Required: False
Position: Named
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

## INPUTS

## OUTPUTS

## NOTES
This breaks the 'do one thing' rule from certain perspectives...
The goal is to decorate an object all in one shot

This abstraction simplifies decorating an object, with a slight trade-off in performance.
For example:
10,000 objects, add a property and typename:
    Add-ObjectDetail:                        ~4.6 seconds
    Add-Member + PSObject.TypeNames.Insert:  ~3 seconds
Initial code borrowed from Shay Levy:
http://blogs.microsoft.co.il/scriptfanatic/2012/04/13/custom-objects-default-display-in-powershell-30/

## RELATED LINKS

[http://ramblingcookiemonster.github.io/Decorating-Objects/](http://ramblingcookiemonster.github.io/Decorating-Objects/)

