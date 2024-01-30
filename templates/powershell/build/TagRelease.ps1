<#
.SYNOPSIS
Set Tag for repository
.DESCRIPTION
Set Tag for repository

.PARAMETER AppVersion
Mandatory. Application version
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\ImportSecretsToKV.ps1 -AppVersion <AppVersion> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AppVersion,
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
Write-Debug "${functionName}:AppVersion=$AppVersion"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force
    $exists = git tag -l "$AppVersion"
    if ($exists) { 
        Write-Host "Tag already exists"
    }
    $giturl=git config --get remote.origin.url
    $gitEndpoint = $giturl.split("/")[-2]
    $gitRepoName = $giturl.split("/")[-1] -replace ".git", ""
    $latestReleaseTag=((Invoke-WebRequest -Uri https://api.github.com/repos/$gitEndpoint/$gitRepoName/releases/latest).Content | ConvertFrom-Json).tag_name
    if ($latestReleaseTag -eq $AppVersion) {
        Write-Host "Release already exists"
        Write-Output "##vso[task.setvariable variable=ReleaseExists]true"
    }
    else {
        Write-Output "##vso[task.setvariable variable=ReleaseExists]false"
    }
    git tag $AppVersion --force
    git push origin $AppVersion
    Write-Host "Tag $AppVersion updated to latest commit"

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