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
.PARAMETER DockerFilePath
Optional. Directory Path of Dockerfile
.PARAMETER TargetFlatform
Optional. Target Flatform for Docker build

.EXAMPLE
.\BuildAndPushDockerImage.ps1  AcrName <AcrName> AcrRepoName <AcrRepoName> ImageVersion <ImageVersion> ImageCachePath <ImageCachePath> Command <Command> PSHelperDirectory <PSHelperDirectory> DockerFilePath <DockerFilePath> TargetFlatform <TargetFlatform>
#> 

[CmdletBinding()]
param(
    [string] $AcrName="",
    [Parameter(Mandatory)]
    [string] $AcrRepoName,
    [Parameter(Mandatory)]
    [string] $ImageVersion,
    [Parameter(Mandatory)]
    [string] $ImageCachePath,    
    [string] $Command = "BuildAndPush",
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [string]$DockerFilePath = "Dockerfile",
    [string]$TargetFlatform = "linux/arm64"
)

function Invoke-DockerBuild {
    param(
        [Parameter(Mandatory)]
        [string]$DockerCacheFilePath,
        [Parameter(Mandatory)]
        [string]$TagName,
        [string]$AcrName = "" ,        
        [string]$DockerFileName = "Dockerfile",
        [string]$TargetFlatform = "linux/arm64"
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:DockerCacheFilePath=$DockerCacheFilePath"
        Write-Debug "${functionName}:TagName=$TagName"
        Write-Debug "${functionName}:AcrName=$AcrName"
        Write-Debug "${functionName}:DockerFileName=$DockerFileName"
        Write-Debug "${functionName}:TargetFlatform=$TargetFlatform"
    }
    process {
        if ("" -ne $AcrName) {
            Invoke-CommandLine -Command "az acr login --name $AcrName"
            Invoke-CommandLine -Command "az acr build -t $TagName -r $AcrName -f $DockerFileName ."
            Invoke-CommandLine -Command "docker pull $AcrName.azurecr.io/$TagName"
            Invoke-CommandLine -Command "docker tag $AcrName.azurecr.io/$TagName $TagName"
            Invoke-CommandLine -Command "az acr repository delete --name $AcrName --image $TagName --yes"            
        }
        else {
            Invoke-CommandLine -Command "docker buildx build -f $DockerFileName -t $TagName --platform=$TargetFlatform ."
        }
        # Save the image for future jobs
        Invoke-CommandLine -Command "docker save -o $DockerCacheFilePath $TagName"   
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Invoke-DockerPush {
    param(
        [Parameter(Mandatory)]
        [string]$DockerCacheFilePath,
        [Parameter(Mandatory)]
        [string]$TagName,
        [Parameter(Mandatory)]
        [string]$AcrName,
        [Parameter(Mandatory)]
        [string]$AcrTagName,
        [string]$DockerFileName = "Dockerfile",
        [string]$TargetFlatform = "linux/arm64"
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:DockerCacheFilePath=$DockerCacheFilePath"
        Write-Debug "${functionName}:TagName=$TagName"
        Write-Debug "${functionName}:AcrName=$AcrName"
        Write-Debug "${functionName}:AcrTagName=$AcrTagName"
        Write-Debug "${functionName}:DockerFileName=$DockerFileName"
        Write-Debug "${functionName}:TargetFlatform=$TargetFlatform"
    }
    process {
        # Load image if exists in cache
        if (Test-Path $DockerCacheFilePath -PathType Leaf) {
            Invoke-CommandLine -Command "docker load -i $DockerCacheFilePath"        
        }
        else {
            Invoke-CommandLine -Command "docker buildx build -f $DockerFileName -t $TagName --platform=$TargetFlatform ."  
            Invoke-CommandLine -Command "docker save -o $DockerCacheFilePath $TagName"          
        }
        Invoke-CommandLine -Command "az acr login --name $AcrName"
        Invoke-CommandLine -Command "docker tag $TagName $AcrTagName"          
        Invoke-CommandLine -Command "docker push $AcrTagName"   
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Invoke-DockerBuildAndPush {
    param(
        [Parameter(Mandatory)]
        [string]$DockerCacheFilePath,
        [Parameter(Mandatory)]
        [string]$TagName,
        [Parameter(Mandatory)]
        [string]$AcrName,
        [Parameter(Mandatory)]
        [string]$AcrTagName,
        [string]$DockerFileName = "Dockerfile",
        [string]$TargetFlatform = "linux/arm64"
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:DockerCacheFilePath=$DockerCacheFilePath"
        Write-Debug "${functionName}:TagName=$TagName"
        Write-Debug "${functionName}:AcrName=$AcrName"
        Write-Debug "${functionName}:AcrTagName=$AcrTagName"
        Write-Debug "${functionName}:DockerFileName=$DockerFileName"
        Write-Debug "${functionName}:TargetFlatform=$TargetFlatform"
    }
    process {
        Invoke-CommandLine -Command "docker buildx build -f $DockerFileName -t $TagName --platform=$TargetFlatform ."
        Invoke-CommandLine -Command "docker save -o $DockerCacheFilePath $TagName"
        Invoke-CommandLine -Command "az acr login --name $AcrName"
        Invoke-CommandLine -Command "docker push $AcrTagName"    
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
Write-Debug "${functionName}:AcrRepoName=$AcrRepoName"
Write-Debug "${functionName}:ImageVersion=$ImageVersion"
Write-Debug "${functionName}:ImageCachePath=$ImageCachePath"
Write-Debug "${functionName}:Command=$Command"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Debug "${functionName}:DockerFilePath=$DockerFilePath"

try {
    Import-Module $PSHelperDirectory -Force

    #Application Image
    Write-Host "Processing Application Docker file: Dockerfile"
    [string]$tagName = $AcrRepoName + ":" + $ImageVersion
    [string]$AcrtagName = $AcrName + ".azurecr.io/image/" + $tagName
    Write-Debug "${functionName}:Docker Image=$tagName"
    Write-Debug "${functionName}:AcrtagName=$AcrtagName"

    [string]$dockerCacheFilePath = $ImageCachePath + "/cache.tar"
    if (!(Test-Path $ImageCachePath -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $ImageCachePath
    } 
    
    if ( $Command.ToLower() -eq 'build' ) {
        Invoke-DockerBuild -DockerCacheFilePath $dockerCacheFilePath -TagName $tagName -AcrName $AcrName -DockerFileName $DockerFilePath -TargetFlatform $TargetFlatform
    }
    elseif ( $Command.ToLower() -eq 'push' ) {
        Invoke-DockerPush -DockerCacheFilePath $dockerCacheFilePath -TagName $tagName -AcrName $AcrName -AcrTagName $AcrtagName -DockerFileName $DockerFilePath -TargetFlatform $TargetFlatform
    }
    else {
        Invoke-DockerBuildAndPush -DockerCacheFilePath $dockerCacheFilePath -TagName $tagName -AcrName $AcrName -AcrTagName $AcrtagName -DockerFileName $DockerFilePath -TargetFlatform $TargetFlatform    
    }    
    if ($LastExitCode -ne 0) {
        Write-Host "##vso[task.complete result=Failed;]DONE"
        $exitCode = -2
    }  

    #DB Migration Image
    [string]$dbMigrationDockerFileName = "db-migration.Dockerfile"
    if (Test-Path $dbMigrationDockerFileName -PathType Leaf) {

        Write-Host "Processing DB Migration Docker file: $dbMigrationDockerFileName"
        [string]$dbMigrationTagName = $AcrRepoName + "-dbmigration:" + $ImageVersion
        [string]$AcrDbMigrationTagName = $AcrName + ".azurecr.io/image/" + $dbMigrationTagName
        Write-Debug "${functionName}:DB Migration Docker Image=$dbMigrationTagName"
        Write-Debug "${functionName}:AcrDbMigrationTagName=$AcrDbMigrationTagName"
    
        [string]$dbDockerCacheFilePath = $ImageCachePath + "/db-cache.tar"
        if (!(Test-Path $ImageCachePath -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $ImageCachePath
        }
        
        if ( $Command.ToLower() -eq 'build' ) {
            Invoke-DockerBuild -DockerCacheFilePath $dbDockerCacheFilePath -TagName $dbMigrationTagName -AcrName $AcrName -DockerFileName $dbMigrationDockerFileName  
        }
        elseif ( $Command.ToLower() -eq 'push' ) {
            Invoke-DockerPush -DockerCacheFilePath $dbDockerCacheFilePath -TagName $dbMigrationTagName -AcrName $AcrName -AcrTagName $AcrDbMigrationTagName -DockerFileName $dbMigrationDockerFileName
        }
        else {
            Invoke-DockerBuildAndPush -DockerCacheFilePath $dbDockerCacheFilePath -TagName $dbMigrationTagName -AcrName $AcrName -AcrTagName $AcrDbMigrationTagName -DockerFileName $dbMigrationDockerFileName
        }    
        if ($LastExitCode -ne 0) {
            Write-Host "##vso[task.complete result=Failed;]DONE"
            $exitCode = -2
        }  
    } 
    else {
        Write-Host "No DB Migration Docker file exist."
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