<#
.SYNOPSIS
Validate json Azure app config file
.DESCRIPTION
Validate json Azure app config file

.PARAMETER SchemaFilePath
Mandatory. Schema file path. 
.PARAMETER ConfigFilePath
Mandatory. App Config file path. 
.EXAMPLE
.\ValidateConfigFile.ps1  -SchemaFilePath <SchemaFilePath> -ConfigFilePath <ConfigFilePath>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $SchemaFilePath,
    [Parameter(Mandatory)]
    [string] $ConfigFilePath
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
Write-Debug "${functionName}:SchemaFilePath=$SchemaFilePath"
Write-Debug "${functionName}:ConfigFilePath=$ConfigFilePath"

try {
    
    $exitCode = 0

    if (Test-Path $ConfigFilePath -PathType Leaf) {
        $json = Get-Content $ConfigFilePath | Out-String
    }
        
    if (($json | Test-Json -SchemaFile $SchemaFilePath) -eq $true) {
        Write-Host "${functionName} JSON File`t`tPassed validation"
    }
    else {
        Write-Host "${functionName} JSON File`t`tFailed validation"
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