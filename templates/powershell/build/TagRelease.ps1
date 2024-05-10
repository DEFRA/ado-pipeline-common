<#
.SYNOPSIS
Set Tag for repository
.DESCRIPTION
Set Tag for repository

.PARAMETER AppVersion
Mandatory. Application version
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.PARAMETER GithubPat
optional. Github Personel Access Token
.EXAMPLE
.\TagRelease.ps1 -AppVersion <AppVersion>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AppVersion,
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [string]$GithubPat
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
Write-Output "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Output "${functionName}:GithubPat=$GithubPat"
try {
    Import-Module $PSHelperDirectory -Force  
    $exists = Invoke-CommandLine -Command "git tag -l '$AppVersion'"
    if ($exists) { 
        Write-Host "Tag already exists"
    }    
    #Invoke-CommandLine -Command "git tag $AppVersion --force"
    #Invoke-CommandLine -Command "git push origin $AppVersion"

    #Write-Host "Tag $AppVersion updated to latest commit"

    [string]$latestReleaseTag = ''
    try {
        [string]$gitOrgName = $($env:BUILD_REPOSITORY_NAME).split("/")[0]
        [string]$gitRepoName = $($env:BUILD_REPOSITORY_NAME).split("/")[1]
        
        $headers = @{
            "Authorization"        = "Bearer " + $GithubPat
            "Accept"               = "application/vnd.github+json"
            "ContentType"          = "application/json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }
    
        Write-Debug "Get the repository ID..."
        [Object]$repo = Invoke-RestMethod -Method Get -Uri ("https://api.github.com/repos/{0}/{1}/releases/latest" -f $gitOrgName, $gitRepoName) -Headers $headers
        Write-Host "repo '$repo'"
        #$latestReleaseTag = ((Invoke-WebRequest -Uri https://api.github.com/repos/$gitOrgName/$gitRepoName/releases/latest).Content | ConvertFrom-Json).tag_name
    }
    catch {
        Write-Host "Release '$AppVersion' could not be found for the repository '$gitRepoName'."
        Write-Host $_
        $exitCode = -2
    }
    
    if ($latestReleaseTag -eq $AppVersion) {
        Write-Host "Release already exists"
        Write-Output "##vso[task.setvariable variable=ReleaseExists]true"
    }
    else {
        Write-Output "##vso[task.setvariable variable=ReleaseExists]true"
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