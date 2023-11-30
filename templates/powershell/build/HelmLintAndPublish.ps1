<#
.SYNOPSIS
Helm lint and/or publish using Azure Service Connection
.DESCRIPTION
Helm lint and/or publish using Azure Service Connection
.PARAMETER AcrName
Optional. Azure Container Registry used to push the helm chart
.PARAMETER ChartVersion
Optional. Chart Version 
.PARAMETER ChartCachePath
Mandatory. Chart Cache Path on the build agent
.PARAMETER Command
Optional. Command to run, lint, build or publish or Default = lint 
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.PARAMETER chartHomeDir
Mandatory. Directory Path of all helm charts
.EXAMPLE
.\HelmLintAndPublish.ps1  AcrName <AcrName> ChartVersion <ChartVersion> ChartCachePath <ChartCachePath> Command <Command>  PSHelperDirectory <PSHelperDirectory> chartHomeDir <chartHomeDir>
#> 

[CmdletBinding()]
param(
    [string] $AcrName,
    [string] $ChartVersion,
    [string] $ChartCachePath = ".",
    [string] $Command = "lint",
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [Parameter(Mandatory)]
    [string]$chartHomeDir
)

function Invoke-HelmLint {
    param(
        [Parameter(Mandatory)]
        [string]$HelmChartName
    )
    begin{
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
    }
    process {
        Write-Host "Build Helm dependencies for $HelmChartName"
        try {
            Invoke-CommandLine -Command "helm dependency build"
        }
        catch {
            Invoke-CommandLine -Command "helm dependency update"
        }

        Write-Host "Linting Helm chart $HelmChartName"
        Invoke-CommandLine -Command "helm lint"
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Invoke-HelmBuild {
    param(
        [Parameter(Mandatory)]
        [string]$HelmChartName,
        [Parameter(Mandatory)]
        [string]$ChartVersion,
        [Parameter(Mandatory)]
        [string]$PathToSaveChart
    )
    begin{
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
    }
    process {
        try {
            Invoke-CommandLine -Command "helm dependency build"
        }
        catch {
            Invoke-CommandLine -Command "helm dependency update"
        }
        
        Invoke-CommandLine -Command "helm package . --version $ChartVersion"

        Write-Host "Saving chart '$HelmChartName-$ChartVersion.tgz' to $ChartCachePath"
        Copy-Item "$helmChartName-$ChartVersion.tgz" -Destination $ChartCachePath -Force 
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Invoke-Publish {
    param(
        [Parameter(Mandatory)]
        [string]$HelmChartName,
        [Parameter(Mandatory)]
        [string]$ChartVersion,
        [Parameter(Mandatory)]
        [string]$PathToSaveChart
    )
    begin{
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
    }
    process {
        Write-Host "Publishing Helm chart $HelmChartName"
        $acrHelmPath = "oci://$AcrName.azurecr.io/helm"
         if (Test-Path $PathToSaveChart -PathType Leaf) { 
            Write-Host "Publising cached chart $acrHelmPath from $PathToSaveChart"
            Invoke-CommandLine -Command "helm push $PathToSaveChart $acrHelmPath"
        }
        else {    
            try {
                Invoke-CommandLine -Command "helm dependency build"
            }
            catch {
                Invoke-CommandLine -Command "helm dependency update"
            }
            Invoke-CommandLine -Command "helm package . --version $ChartVersion"

            Write-Host "Saving chart '$HelmChartName-$ChartVersion.tgz' to $PathToSaveChart"
            Copy-Item "$HelmChartName-$ChartVersion.tgz" -Destination $PathToSaveChart -Force          
            
            Write-Host "Publising chart $acrHelmPath from $PathToSaveChart"
            Invoke-CommandLine -Command "helm push $chartCacheFilePath $acrHelmPath"
        }
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

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
        if ($chartDirectory) {
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
                
            switch ($Command.ToLower()) {
                'lint' {
                    Invoke-HelmLint -HelmChartName $helmChartName
                }
                'publish' {
                    Invoke-CommandLine -Command "az acr login --name $AcrName"
                    Invoke-Publish -HelmChartName $helmChartName -ChartVersion $ChartVersion -PathToSaveChart $chartCacheFilePath
                }
                'build' {                    
                    Invoke-HelmBuild -HelmChartName $helmChartName -ChartVersion $ChartVersion -PathToSaveChart $ChartCachePath
                }
            }
        }
        else {
            Write-Host "ChartDirectory does not exit for $helmChartName."
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

