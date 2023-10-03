<#
.SYNOPSIS
Docker build and/or push using Azure Service Connection
.DESCRIPTION
Docker build and/or push using Azure Service Connection
.PARAMETER AcrName
Optional. Azure Container Registry used to push the container
.PARAMETER AcrRepoName
Mandatory. Name of the Repo to push the container in ACR
.PARAMETER ImageVersion
Mandatory. Container image Version
.PARAMETER ImageCachePath
Mandatory. Container image Cache Path on the build agent
.PARAMETER Command
Optional. Command to run, Build or Push or Default = BuildAndPush  
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module

.EXAMPLE
.\BuildAndPushDockerImage.ps1  AcrName <AcrName> AcrRepoName <AcrRepoName> ImageVersion <ImageVersion> ImageCachePath <ImageCachePath> Command <Command> PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [string] $AcrName,
    [Parameter(Mandatory)]
    [string] $AcrRepoName,
    [Parameter(Mandatory)]
    [string] $ImageVersion,
    [Parameter(Mandatory)]
    [string] $ImageCachePath,    
    [string] $Command = "BuildAndPush",
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
Write-Debug "${functionName}:ImageVersion=$ImageVersion"
Write-Debug "${functionName}:ImageCachePath=$ImageCachePath"
Write-Debug "${functionName}:Command=$Command"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {
    Import-Module $PSHelperDirectory -Force

    $tagName = $AcrRepoName + ":" + $ImageVersion
    $AcrtagName = $AcrName + ".azurecr.io/image/" + $AcrRepoName + ":" + $ImageVersion
    Write-Debug "${functionName}:Docker Image=$tagName"

    $dockerCacheFilePath = $ImageCachePath + "/cache.tar"
    if (!(Test-Path $ImageCachePath -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $ImageCachePath
    }

    $exitCode = 0
    
    if ( $Command.ToLower() -eq 'build' ) {
        Invoke-CommandLine -Command "docker buildx build -t $tagName --platform=linux/arm64 ."
        # Save the image for future jobs
        Invoke-CommandLine -Command "docker save -o $dockerCacheFilePath $tagName"      
    }
    elseif ( $Command.ToLower() -eq 'push' ) {
        # Load image if exists in cache
        if (Test-Path $dockerCacheFilePath -PathType Leaf) {
            Invoke-CommandLine -Command "docker load -i $dockerCacheFilePath"        
        }
        else {
            Invoke-CommandLine -Command "docker buildx build -t $tagName --platform=linux/arm64 ."  
             Invoke-CommandLine -Command "docker save -o $dockerCacheFilePath $tagName"          
        }
        Invoke-CommandLine -Command "az acr login --name $AcrName"
        Invoke-CommandLine -Command "docker tag $tagName $AcrtagName"          
        Invoke-CommandLine -Command "docker push $AcrtagName"   
    }
    else {
        Invoke-CommandLine -Command "docker buildx build -t $tagName --platform=linux/arm64 ."
        Invoke-CommandLine -Command "docker save -o $dockerCacheFilePath $tagName"
        Invoke-CommandLine -Command "az acr login --name $AcrName"
        Invoke-CommandLine -Command "docker push $AcrtagName"    
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