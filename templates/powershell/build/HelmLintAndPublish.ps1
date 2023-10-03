<#
.SYNOPSIS
Helm lint and/or publish using Azure Service Connection
.DESCRIPTION
Helm lint and/or publish using Azure Service Connection
.PARAMETER AcrName
Optional. Azure Container Registry used to push the helm chart
.PARAMETER AcrRepoName
Optional. Name of the Repo to push the chart in ACR
.PARAMETER ChartVersion
Optional. Chart Version 
.PARAMETER ChartCachePath
Mandatory. Chart Cache Path on the build agent
.PARAMETER Command
Optional. Command to run, lint or publish or Default = LintAndPublish 
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\HelmLintAndPublish.ps1  AcrName <AcrName> AcrRepoName <AcrRepoName> ChartVersion <ChartVersion> ChartCachePath <ChartCachePath> Command <Command>  PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [string] $AcrName,
    [string] $AcrRepoName,
    [string] $ChartVersion,
    [string] $ChartCachePath = ".",
    [string] $Command = "LintAndPublish",
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
Write-Debug "${functionName}:AcrName=$AcrName"
Write-Debug "${functionName}:AcrRepoName=$AcrRepoName"
Write-Debug "${functionName}:ChartVersion=$ChartVersion"
Write-Debug "${functionName}:ChartCachePath=$ChartCachePath"
Write-Debug "${functionName}:Command=$Command"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {
    Import-Module $PSHelperDirectory -Force
    
    $chartCacheFilePath = $ChartCachePath + "/$AcrRepoName-$ChartVersion.tgz"
    if (!(Test-Path $ChartCachePath -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $ChartCachePath
    }
    $chartDirectory = Get-ChildItem -Recurse -Path ./ -Include Chart.yaml | Where-Object { $_.PSIsContainer -eq $false }
    if (  $null -ne $chartDirectory ) {        
        if ( $null -ne $chartDirectory.DirectoryName ) {
            Set-Location $chartDirectory.DirectoryName
        }   
    }

    $exitCode = 0
    
    $tagName = $AcrName + ".azurecr.io/helm" + $AcrRepoName + ":" + $ChartVersion
    Write-Debug "${functionName}:Helm Tag=$tagName"
        
    if ( $Command.ToLower() -eq 'lint' ) {
        Invoke-CommandLine -Command "helm dependency build"
        Invoke-CommandLine -Command "helm lint"
    }
    elseif ( $Command.ToLower() -eq 'publish' ) {
        Invoke-CommandLine -Command "az acr login --name $AcrName"   
        # Load chart if exists in cache
        if (Test-Path $chartCacheFilePath -PathType Leaf) {      
            Invoke-CommandLine -Command "helm push $chartCacheFilePath oci://$AcrName.azurecr.io/helm"
        }
        else {    
            Invoke-CommandLine -Command "helm dependency build"
            Invoke-CommandLine -Command "helm package . --version $ChartVersion"
            # Save the chart for future jobs
            Copy-Item $AcrRepoName-$ChartVersion.tgz -Destination $ChartCachePath -Force                
            Invoke-CommandLine -Command "helm push $chartCacheFilePath oci://$AcrName.azurecr.io/helm"
        }        
    }
    elseif ( $Command.ToLower() -eq 'build' ) {
        Invoke-CommandLine -Command "helm dependency build"
        Invoke-CommandLine -Command "helm package . --version $ChartVersion"
        # Save the chart for future jobs
        Copy-Item $AcrRepoName-$ChartVersion.tgz -Destination $ChartCachePath -Force            
    }    
    if ($LastExitCode -ne 0) {
        Write-Host "##vso[task.complete result=Failed;]DONE"
        $exitCode = -2
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
