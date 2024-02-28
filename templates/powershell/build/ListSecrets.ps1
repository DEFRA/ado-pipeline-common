<#
.SYNOPSIS
List all variables from provided list of groups
.DESCRIPTION
List all variables from provided list of groups

.PARAMETER VariableGroups
Mandatory. SemiColon seperated variable groups
.PARAMETER EnvName
Mandatory. Environment Name
.PARAMETER VarFilter
Mandatory. variable filter default *
.PARAMETER -ServiceConnection
Mandatory. serviceConnection Name
.PARAMETER AppKeyVault
Mandatory. appKeyVault Name
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\ListSecrets.ps1  -VariableGroups <VariableGroups> -EnvName <EnvName>  -ServiceConnection <ServiceConnection>  -AppKeyVault <AppKeyVault> -VarFilter <VarFilter> PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $VariableGroups,
    [Parameter(Mandatory)]
    [string] $EnvName,  
    [Parameter(Mandatory)]        
    [string] $ServiceConnection,       
    [Parameter(Mandatory)]        
    [string] $AppKeyVault,        
    [string] $VarFilter = '*',    
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
Write-Debug "${functionName}:ServiceConnection=$ServiceConnection"
Write-Debug "${functionName}:AppKeyVault=$AppKeyVault"
Write-Debug "${functionName}:VarFilter=$VarFilter"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force

    $exitCode = 0

    $variablesArray = @()

    Invoke-CommandLine -Command "az devops configure --defaults organization=$ENV:DevOpsUri"
    Invoke-CommandLine -Command "az devops configure --defaults project=$ENV:DevOpsProject"
    $VariableGroupsArray = $VariableGroups -split ";"
    foreach ($VariableGroup in $VariableGroupsArray) {
        if ($VariableGroup.contains($EnvName)) {
            Write-Host "${functionName} :$VariableGroup"                  
            $group = Invoke-CommandLine -Command "az pipelines variable-group list  --group-name $VariableGroup --detect true | ConvertFrom-Json"            
            $groupId = $group.id
            Write-Host "groupId :$groupId"  
            $variable_group = Invoke-CommandLine -Command "az pipelines variable-group variable list --group-id $groupId --detect true  | ConvertFrom-Json"  
            Write-Host "variable_group :$variable_group" 
            $variables = $variable_group.psobject.Properties.Name
            Write-Host "variables :$variables" 
            foreach ($variable in $variables) {
                if ($VarFilter.Equals('*') -or $variable.contains($VarFilter)) {
                    $variablesArray += $variable
                }
            }
        }
        else {
            Write-Host "${functionName} :$VariableGroup not related to env: $EnvName"        
        }
    }  
    if ($variablesArray.Length -gt 0) {
        $variablesArrayString = $variablesArray -join ';'
        Write-Output "##vso[task.setvariable variable=secretVariables;isOutput=true]$variablesArrayString"     
        Write-Host "variablesArrayString :$variablesArrayString"
        $buildQueue = Invoke-CommandLine -Command "az pipelines run --project $ENV:DevOpsProject --name $ENV:ImportPipelineName --branch $ENV:ImportPipelineBranch --parameters 'secretNames=$variablesArrayString' 'serviceConnection=$ServiceConnection' 'appKeyVault=$AppKeyVault' 'variableGroups=$VariableGroups' 'PSHelperDirectory=$PSHelperDirectory'  | ConvertFrom-Json" 
        Write-Host "buildQueue :$buildQueue"
        $buildNumber = $buildQueue.id
        if ($null -ne $buildNumber) {
            # Get the status of triggered build
            $buildDetails = (az pipelines build show --id $buildQueue.id --detect true --organization $ENV:DevOpsUri --project $ENV:DevOpsProject) | ConvertFrom-Json

            while ($buildDetails.status -ne "completed") {
                Start-Sleep -Seconds 10
                if ($buildDetails.status -eq "notStarted") {
                    Write-Host $buildNumber -ForegroundColor Green
                }
                if ($buildDetails.status -eq "canceled" -Or $buildDetails.status -eq "failed") {
                    Write-Error "The build number $buildNumber is $buildDetails.status"
                }
                # Get the status of the triggered build again
                $buildDetails = (az pipelines build show --id $buildQueue.id --detect true --organization $ENV:DevOpsUri --project $ENV:DevOpsProject) | ConvertFrom-Json
            }		
        }
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