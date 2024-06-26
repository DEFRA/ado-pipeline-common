<#
.SYNOPSIS
Deploy backstage app
.DESCRIPTION
Deploy backstage app
.PARAMETER Command
Mandatory. Command to be executed Build or Deploy
.PARAMETER AppName
Optional. Name of the app
.PARAMETER ResourceGroup
Optional. Name of the Resource group
.PARAMETER Filepath
Optional. File Path of the yaml file
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module

.EXAMPLE
.\BuildAndDeployBackstageApp.ps1 -Command <Command> -AppName <AppName> -ResourceGroup <ResourceGroup> -Filepath <Filepath> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Command,
    [string]$AppName,
    [string]$ResourceGroup,
    [string]$Filepath,
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [string]$WorkingDirectory = $PWD
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
Write-Output "${functionName}:Command=$Command"
Write-Output "${functionName}:AppName=$AppName"
Write-Output "${functionName}:ResourceGroup=$ResourceGroup"
Write-Output "${functionName}:Filepath=$Filepath"
Write-Output "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {
     
    Import-Module $PSHelperDirectory -Force   

    Push-Location $WorkingDirectory

    if ("Build" -eq $Command) {
        yarn install --frozen-lockfile
        yarn tsc
        yarn build:backend    
        Write-Output "${functionName}:Build Complete"    
    }
    elseif ("Test" -eq $Command) {
        yarn test:all
        yarn test:cobertura 
        Write-Output "${functionName}:Test Complete"    
    }
    elseif ("Deploy" -eq $Command) {
        $obj = Invoke-CommandLine -Command "az containerapp show -n $AppName -g $ResourceGroup --query id " -IgnoreErrorCode
        if ($null -ne $obj) {
            Write-Output "${functionName}: App already exists. Updating"
            Invoke-CommandLine -Command "az containerapp update -n $AppName -g $ResourceGroup  --yaml $Filepath"   
        }
        else {
            Invoke-CommandLine -Command "az containerapp create -n $AppName -g $ResourceGroup  --yaml $Filepath"   
        }
                 
        Write-Output "${functionName}:Deploy Complete" 
    }
    else {
        Write-Output "${functionName}:Invalid Command"
        $exitCode = -2
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
    Pop-Location
    exit $exitCode
}