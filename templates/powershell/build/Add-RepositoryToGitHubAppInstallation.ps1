<#
.SYNOPSIS
     Adds the supplied GitHub Repository to an installed App Installation
.DESCRIPTION
    Adds the supplied GitHub Repository to an installed App Installation. Used for when App Installations are selected repos only.
.PARAMETER GithubPat
    Mandatory. Github Personel Access Token
.PARAMETER AppInstallationSlug
     Name of the App Installation
.PARAMETER PSHelperDirectory
    Mandatory. Directory Path of PSHelper module
.EXAMPLE
    .\Add-RepositoryToGitHubAppInstallation.ps1 -GithubPat <GithubPat> -AppInstallationSlug <AppInstallationSlug> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$GithubPat,
    [Parameter(Mandatory)]
    [string]$AppInstallationSlug,
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
Write-Debug "${functionName}:GithubPat=$GithubPat"
Write-Debug "${functionName}:AppInstallationSlug=$AppInstallationSlug"

try {
    Import-Module $PSHelperDirectory -Force  
    
    Write-Debug "Get Github Org & Repo name"
    [string]$giturl = Invoke-CommandLine -Command "git config --get remote.origin.url"
    [string]$gitRepoName = $giturl.split("/")[-1] -replace ".git", ""
    [string]$gitOrgName = $giturl.split("/")[3] -replace "/$gitRepoName.git", ""
    Write-Debug "Git config URL: $giturl"

    Write-Host "$(Build.Repository.Name)"
    Write-Host "$(Build.Repository.Uri)"
    Write-Host "$(Build.Repository.ID)"

    $headers = @{
        "Authorization"        = "Bearer " + $GithubPat
        "Accept"               = "application/vnd.github+json"
        "ContentType"          = "application/json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    
    Write-Debug "Get the repository ID..."
    [Object]$repo = Invoke-RestMethod -Method Get -Uri ("https://api.github.com/repos/{0}/{1}" -f $gitOrgName, $gitRepoName) -Headers $headers
    [string]$repoId = $repo.id

    Write-Debug "Get App Installation ID..."
    [Object]$apps = Invoke-RestMethod -Method Get -Uri ("https://api.github.com/orgs/{0}/installations" -f $gitOrgName) -Headers $headers
    [Object]$installation = $apps.installations | 
                    Where-Object {$_.app_slug -eq $AppInstallationSlug}
    [string]$installationId = $installation.id

    Write-Output "App Installation ID for App Name: $AppInstallationSlug is: $installationId for Github Organisation, Repository Name, and RepoId: $gitOrgName / $gitRepoName / $repoId"

    Write-Debug "Add Repository to App Installation..."
    $response = Invoke-WebRequest -Method Put -Uri ("https://api.github.com/user/installations/{0}/repositories/{1}" -f $installationId, $repoId) -Headers $headers    

    if ($response -and $response.StatusCode -eq "204") {
        Write-Output "Status 204: The Repository: $gitRepoName has been added successfully to the GitHub App Installation: $AppInstallationSlug for the Org: $gitOrgName"
        Write-Debug $response
    }
    else {
        Write-Output "Error: Unable to Add Repo to App Installation: Response code: $response.StatusCode"
        Write-Debug $response
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