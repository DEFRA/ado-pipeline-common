<#
.SYNOPSIS
Helm lint and/or publish using Azure Service Connection
.DESCRIPTION
Helm lint and/or publish using Azure Service Connection
.PARAMETER AcrName
Optional. Azure Container Registry used to push the helm chart
.PARAMETER ImageRepoName
Optional. Name of the Repo to push the chart in ACR
.PARAMETER ChartVersion
Optional. Chart Version 
.PARAMETER ChartCachePath
Mandatory. Chart Cache Path on the build agent
.PARAMETER Command
Optional. Command to run, lint or publish or Default = LintAndPublish 
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.PARAMETER chartHomeDir
Mandatory. Directory Path of all helm charts
.EXAMPLE
.\HelmLintAndPublish.ps1  AcrName <AcrName> ImageRepoName <ImageRepoName> ChartVersion <ChartVersion> ChartCachePath <ChartCachePath> Command <Command>  PSHelperDirectory <PSHelperDirectory> chartHomeDir <chartHomeDir>
#> 

[CmdletBinding()]
param(
    [string] $AcrName,
    [string] $ImageRepoName,
    [string] $ChartVersion,
    [string] $ChartCachePath = ".",
    [string] $Command = "LintAndPublish",
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [Parameter(Mandatory)]
    [string]$chartHomeDir
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
Write-Debug "${functionName}:ImageRepoName=$ImageRepoName"
Write-Debug "${functionName}:ChartVersion=$ChartVersion"
Write-Debug "${functionName}:ChartCachePath=$ChartCachePath"
Write-Debug "${functionName}:Command=$Command"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Debug "${functionName}:chartHomeDir=$chartHomeDir"

try {

    Import-Module $PSHelperDirectory -Force
    
    $helmChartsDirList = Get-ChildItem -Path $chartHomeDir

    $helmChartsDirList | ForEach-Object {

        $helmChartName = $_.Name
        Write-Debug "${functionName}:helmChartName=$helmChartName"

        $chartDirectory = Get-ChildItem -Recurse -Path $(Join-Path -Path $chartHomeDir -ChildPath $helmChartName)  -Include Chart.yaml | Where-Object { $_.PSIsContainer -eq $false }
        
        Write-Debug "${functionName}:Changing location to $($chartDirectory.DirectoryName)"
        Push-Location $chartDirectory.DirectoryName
        Write-Debug "${functionName}:Current location is '$(Get-Location)'"
        
        Write-Host "Working on Chart: $helmChartName in directory: $chartDirectory"
        $chartCacheFilePath = Join-Path -Path $ChartCachePath -ChildPath "$helmChartName-$ChartVersion.tgz"
        Write-Debug "${functionName}:chartCacheFilePath=$chartCacheFilePath"
    
        if (!(Test-Path $ChartCachePath -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $ChartCachePath
            Write-Host "Created Chart Cache Path: $ChartCachePath"
        }
        
        Invoke-CommandLine -Command "az acr login --name $AcrName"

        if ( $Command.ToLower() -eq 'lint' ) {
            Invoke-CommandLine -Command "helm dependency build"
            Invoke-CommandLine -Command "helm lint"
        }
        elseif ( $Command.ToLower() -eq 'publish' ) {
            # Load chart if exists in cache
            if (Test-Path $chartCacheFilePath -PathType Leaf) {      
                Invoke-CommandLine -Command "helm push $chartCacheFilePath oci://$AcrName.azurecr.io/helm"
            }
            else {    
                Invoke-CommandLine -Command "helm dependency build"
                Invoke-CommandLine -Command "helm package . --version $ChartVersion"
                # Save the chart for future jobs
                Copy-Item $helmChartName-$ChartVersion.tgz -Destination $ChartCachePath -Force                
                Invoke-CommandLine -Command "helm push $chartCacheFilePath oci://$AcrName.azurecr.io/helm"
            }
        }
        elseif ( $Command.ToLower() -eq 'build' ) {
            Invoke-CommandLine -Command "helm dependency build"
            Invoke-CommandLine -Command "helm package . --version $ChartVersion"
            # Save the chart for future jobs
            Copy-Item $helmChartName-$ChartVersion.tgz -Destination $ChartCachePath -Force            
        }
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
    Pop-Location
}


-ImageRepoName 'ffc-demo-web' -ChartVersion '4.32.3' -ChartCachePath 'D:\workspace\defra-ffc\ffc-demo-web\helm' -Command 'Lint'  -PSHelperDirectory 'D:\workspace\defra\ado-pipeline-common\templates\powershell\modules\ps-helpers' -chartHomeDir 'D:\workspace\defra-ffc\ffc-demo-web\helm'
