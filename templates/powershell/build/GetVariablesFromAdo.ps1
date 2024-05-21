<#
.SYNOPSIS
    Retrieves all variables from the specified variable groups in Azure DevOps.

.DESCRIPTION
    This script retrieves all variables from the provided list of variable groups in Azure DevOps. 
    It can filter variables based on the provided filters and can also filter based on ProgrammeName.

.PARAMETER VariableGroups
    Mandatory. A semi-colon separated list of variable groups to retrieve variables from.

.PARAMETER ProgrammeName
    Optional. The name of the programme to filter variables by.

.PARAMETER EnvName
    Mandatory. The name of the environment to retrieve variables for.

.PARAMETER VarFilter
    Optional. A semi-colon separated list of variable filters to apply when retrieving variables.

.PARAMETER PSHelperDirectory
    Mandatory. The directory path of the PSHelper module.

.EXAMPLE
    .\GetVariablesFromAdo.ps1  -VariableGroups "Group1;Group2" -EnvName "Production" -ProgrammeName "Programme1" -VarFilter "Filter1;Filter2"  -PSHelperDirectory "C:\PSHelper" 
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VariableGroups,
    [Parameter(Mandatory)]
    [string]$EnvName,
    [string]$ProgrammeName,
    [string]$VarFilter,
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory
)

function Set-AzureDevOpsDefaults {
    param(
        [Parameter(Mandatory = $true)][string]$Organization,
        [Parameter(Mandatory = $true)][string]$Project
    )

    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:Organization=$Organization"
        Write-Debug "${functionName}:Project=$Project"
    }
    process {
        Invoke-CommandLine -Command "az devops configure --defaults organization=$Organization"
        Invoke-CommandLine -Command "az devops configure --defaults project=$Project"
    }

    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Get-VariableGroups {
    param(
        [Parameter(Mandatory = $true)][string]$VariableGroups,
        [Parameter(Mandatory = $true)][string]$EnvName,
        [Parameter(Mandatory = $false)][string]$ProgrammeName
    )

    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:VariableGroups=$VariableGroups"
        Write-Debug "${functionName}:EnvName=$EnvName"
        Write-Debug "${functionName}:ProgrammeName=$ProgrammeName"
    }

    process {

        $variableGroupsArray = $VariableGroups -split ";"
        $variableGroupsHashtable = @{}

        foreach ($variableGroup in $variableGroupsArray) {
            if ([string]::IsNullOrEmpty($ProgrammeName) -or $variableGroup -like $ProgrammeName -or $variableGroup -match $ProgrammeName) {        
                if ($variableGroup.Contains('<environment>')) {
                    $variableGroup = $variableGroup -replace '<environment>', $EnvName
                }
                if ($variableGroup.Contains($EnvName)) {
                    Write-Debug "Getting variables for VariableGroup :$variableGroup"
                    
                    $group = Invoke-CommandLine -Command "az pipelines variable-group list --group-name $variableGroup --detect true | ConvertFrom-Json"            
                    $groupId = $group.id
                    Write-Debug "groupId :$groupId"

                    $variable_group = Invoke-CommandLine -Command "az pipelines variable-group variable list --group-id $groupId --detect true  | ConvertFrom-Json"  
                    $variables = $variable_group.psobject.Properties.Name
                    Write-Debug "variables :$variables"

                    $variableGroupsHashtable[$variableGroup] = $variables
                }
                else {
                    Write-Host "VariableGroup: $variableGroup not related to env: $EnvName"        
                }
            }
            else {
                Write-Host "VariableGroup :$variableGroup does not match with ProgrammeName :$ProgrammeName"  
            }
        } 
        return $variableGroupsHashtable
    }

    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Get-FinalVariables {
    param(
        [Parameter(Mandatory = $true)][hashtable]$VariableGroupsHashtable,
        [Parameter(Mandatory = $false)][string]$VarFilter
    )

    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:VariableGroupsHashtable=$VariableGroupsHashtable"
        Write-Debug "${functionName}:VarFilter=$VarFilter"
    }
    process {

        $varFilterArray = @()
        $variablesArray = @()

        if (-not [string]::IsNullOrEmpty($VarFilter)) {
            $varFilterArray = $VarFilter -split ";"
        } 

        foreach ($variableGroup in $VariableGroupsHashtable.Keys) {
            foreach ($variable in $VariableGroupsHashtable[$variableGroup]) {
                if ($varFilterArray.Count -gt 0) {
                    foreach ($filter in $varFilterArray) {
                        if ($variable -like $filter -or $variable -match $filter) {      
                            $variablesArray += $variable             
                            continue
                        }
                        else {
                            Write-Debug "Variable :$variable does not match with filter :$filter"  
                        }
                    }
                }
                else {                  
                    $variablesArray += $variable
                }
            }
        }

        return $variablesArray
    }

    end {
        Write-Debug "${functionName}:Exited"
    }
}

Set-StrictMode -Version 3.0

[string]$functionName = $MyInvocation.MyCommand
[datetime]$startTime = [datetime]::UtcNow

[int]$exitCode = -1
[bool]$setHostExitCode = (Test-Path -Path ENV:TF_BUILD) -and ($ENV:TF_BUILD -eq "true")
[bool]$enableDebug = (Test-Path -Path ENV:SYSTEM_DEBUG) -and ($ENV:SYSTEM_DEBUG -eq "true")

Set-Variable -Name ErrorActionPreference -Value Continue -scope global
Set-Variable -Name InformationPreference -Value Continue -Scope global

if ($enableDebug) {
    Set-Variable -Name VerbosePreference -Value Continue -Scope global
    Set-Variable -Name DebugPreference -Value Continue -Scope global
}

Write-Host "${functionName} started at $($startTime.ToString('u'))"
Write-Debug "${functionName}:VariableGroups=$VariableGroups"
Write-Debug "${functionName}:EnvName=$EnvName"
Write-Debug "${functionName}:ProgrammeName=$ProgrammeName"
Write-Debug "${functionName}:VarFilter=$VarFilter"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force
    
    Set-AzureDevOpsDefaults -Organization $ENV:DevOpOrganization -Project $ENV:DevOpsProject

    $variableGroupsHashtable = Get-VariableGroups -VariableGroups $VariableGroups -EnvName $EnvName -ProgrammeName $ProgrammeName

    $variablesArray = Get-FinalVariables -VariableGroupsHashtable $VariableGroupsHashtable -VarFilter $VarFilter
    
    Write-Host "variables:$variablesArray" 

    if ($variablesArray.Count -gt 0) {
        $secretVariableNamesJson = $variablesArray | ConvertTo-Json -Compress 
        [hashtable]$body = @{variables = @() }
        foreach ($var in $variablesArray) {
            $body.variables += @([ordered]@{name = $var; value = "`$($var)" })
        }
        $json = $body.variables | ConvertTo-Json -Compress 
        Write-Host "##vso[task.setvariable variable=secretVariablesJson;]$json"
        Write-Host "##vso[task.setvariable variable=secretVariableNamesJson;]$secretVariableNamesJson"
    }
    else {
        Write-Host "##vso[task.setvariable variable=secretVariablesJson;]'[]'"
        Write-Host "##vso[task.setvariable variable=secretVariableNamesJson;]'[]'"
    }
    
    $exitCode = 0
}
catch {
    $exitCode = -2
    Write-Error $_.Exception.ToString()
    throw $_.Exception
}
finally {
    [DateTime]$endTime = [DateTime]::UtcNow
    [Timespan]$duration = $endTime.Subtract($startTime)

    Write-Host "${functionName} finished at $($endTime.ToString('u')) (duration $($duration -f 'g')) with exit code $exitCode"
    if ($setHostExitCode) {
        Write-Debug "${functionName}:Setting host exit code"
        $host.SetShouldExit($exitCode)
    }
    exit $exitCode
}

