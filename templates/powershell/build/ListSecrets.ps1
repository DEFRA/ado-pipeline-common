<#
.SYNOPSIS
List all variables from provided list of groups
.DESCRIPTION
List all variables from provided list of groups

.PARAMETER VariableGroups
Mandatory. SemiColon seperated variable groups
.PARAMETER ProgrammeName
Optional. ProgrammeName Name
.PARAMETER EnvName
Mandatory. Environment Name
.PARAMETER VarFilter
Optional. SemiColon seperated variable filters
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module


.EXAMPLE
.\ListAndImportSecretsToKV.ps1  -VariableGroups <VariableGroups> -EnvName <EnvName> -ProgrammeName <ProgrammeName> -VarFilter <VarFilter>  -PSHelperDirectory <PSHelperDirectory> 
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
    $variablesArray = @()
    $VarFilterArray = ""
    Invoke-CommandLine -Command "az devops configure --defaults organization=$ENV:DevOpOrganization"
    Invoke-CommandLine -Command "az devops configure --defaults project=$ENV:DevOpsProject"
    $VariableGroupsArray = $VariableGroups -split ";"
    if (-not [string]::IsNullOrEmpty($VarFilter)) {
        $VarFilterArray = $VarFilter -split ";"
    } 
    foreach ($VariableGroup in $VariableGroupsArray) {
        if ([string]::IsNullOrEmpty($ProgrammeName) -or $VariableGroup -like $ProgrammeName -or $VariableGroup -match $ProgrammeName) {        
            if ($VariableGroup.Contains('<environment>')) {
                $VariableGroup = $VariableGroup -replace '<environment>', $EnvName
            }
            if ($VariableGroup.Contains($EnvName)) {
                Write-Host "VariableGroup :$VariableGroup"                  
                $group = Invoke-CommandLine -Command "az pipelines variable-group list --group-name $VariableGroup --detect true | ConvertFrom-Json"            
                $groupId = $group.id
                $variable_group = Invoke-CommandLine -Command "az pipelines variable-group variable list --group-id $groupId --detect true  | ConvertFrom-Json"  
                $variables = $variable_group.psobject.Properties.Name
                Write-Host "variables :$variables" 
                foreach ($variable in $variables) {
                    if (-not [string]::IsNullOrEmpty($VarFilterArray)) {
                        foreach ($filter in $VarFilterArray) {
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
            else {
                Write-Host "${functionName} :$VariableGroup not related to env: $EnvName"        
            }
        }
        else {
            Write-Host "VariableGroup :$VariableGroup does not match with ProgrammeName :$ProgrammeName"  
        }
    }  

    Write-Host "variablesArray :$variablesArray" 
    if ($variablesArray.Count -gt 0) {
        $secretVariableNamesJson = $variablesArray | ConvertTo-Json -Compress 
        [hashtable]$body = @{}
        $body.variables = @()
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

