<#
.SYNOPSIS
List all variables from provided list of groups
.DESCRIPTION
List all variables from provided list of groups

.PARAMETER VariableGroups
Mandatory. SemiColon seperated variable groups
.PARAMETER EnvName
Mandatory. Environment Name
.PARAMETER ServiceName
Mandatory. Service Name
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\ListSecrets.ps1  -VariableGroups <VariableGroups> -EnvName <EnvName> -ServiceName <ServiceName> PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $VariableGroups,
    [Parameter(Mandatory)]
    [string] $EnvName,      
    [Parameter(Mandatory)]
    [string] $ServiceName,    
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
Write-Debug "${functionName}:ServiceName=$ServiceName"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force

    $exitCode = 0

    $variablesArray = @()

    Invoke-CommandLine -Command "az devops configure --defaults organization=$ENV:DevOpsUri"
    Invoke-CommandLine -Command "az devops configure --defaults project=$ENV:DevOpsProject"

    $VariableGroupsArray = $VariableGroups -split ";"
    foreach ($VariableGroup in $VariableGroupsArray) {
        if ($VariableGroup.contains($ServiceName + "-" + $EnvName)) {
            Write-Host "${functionName} :$VariableGroup"                  
            $group = Invoke-CommandLine -Command "az pipelines variable-group list  --group-name $VariableGroup --detect true | ConvertFrom-Json"            
            $groupId = $group.id
            $variable_group = Invoke-CommandLine -Command "az pipelines variable-group variable list --group-id $groupId --detect true  | ConvertFrom-Json"  
            $variables = $variable_group.psobject.Properties.Name
            foreach ($variable in $variables) {
                if ($variable.contains($ServiceName)) {
                    $variablesArray += $variable
                }
            }
        }else{
            Write-Host "${functionName} :$VariableGroup not related to env: $EnvName"        
        }
    }  
    if ($variablesArray.Length -gt 0) {
        $variablesArrayString = $variablesArray -join ';'
        Write-Output "##vso[task.setvariable variable=secretVariables]$variablesArrayString"     
        Write-Host "${functionName} :$variablesArrayString"
    }
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