<#
.SYNOPSIS
 Set Build details such as build number
.DESCRIPTION
 Set Build details such as build number
.PARAMETER RunDate
Mandatory. Pipeline rundate
.PARAMETER Revision
Mandatory. Pipeline Revision
.PARAMETER AppVersion
Mandatory. AppVersion to Set
.EXAMPLE
.\Set-BuildDetails.ps1 -RunDate <RunDate> -Revision <Revision> -AppVersion <AppVersion>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $RunDate,
    [Parameter(Mandatory)]
    [string] $Revision,
    [Parameter(Mandatory)]
    [string] $AppVersion = ""
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
Write-Debug "${functionName}:AppVersion=$AppVersion"
Write-Debug "${functionName}:RunDate=$RunDate"
Write-Debug "${functionName}:Revision=$Revision"

try {
    
    $exitCode = 0
    Write-Host "##vso[build.updatebuildnumber]$AppVersion-$RunDate-$Revision"   
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