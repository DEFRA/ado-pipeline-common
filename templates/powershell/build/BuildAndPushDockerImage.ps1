<#
.SYNOPSIS
Docker build and/or push using Azure Service Connection
.DESCRIPTION
Docker build and/or push using Azure Service Connection
.PARAMETER AcrName
Optional. Azure Container Registry used to push the container. If provided for Build command then it will be used to build the container image. If not provided then local docker build will be used.
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
.PARAMETER WorkingDirectory
Optional. Working Directory for Docker build
.PARAMETER TargetPlatform
Optional. Target Flatform for Docker build
.PARAMETER BaseImagesAcrName
Optional. Azure Container Registry used to pull the base images.

.EXAMPLE
.\BuildAndPushDockerImage.ps1  -AcrName <AcrName> -AcrRepoName <AcrRepoName> -ImageVersion <ImageVersion> -ImageCachePath <ImageCachePath> `
                               -Command <Command> -PSHelperDirectory -<PSHelperDirectory> -DockerFilePath <DockerFilePath> `
                               -WorkingDirectory <WorkingDirectory> -TargetPlatform <TargetPlatform> -BaseImagesAcrName <BaseImagesAcrName>
#> 

[CmdletBinding()]
param(
    [string] $AcrName = "",
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
    [string]$WorkingDirectory = $PWD,
    [string]$TargetPlatform = "linux/amd64",
    [string] $BaseImagesAcrName =$null
)

function Invoke-DockerBuild {
    param(
        [Parameter(Mandatory)]
        [string]$DockerCacheFilePath,
        [Parameter(Mandatory)]
        [string]$TagName,
        [string]$AcrName = "" ,        
        [string]$DockerFileName = "Dockerfile",
        [string]$WorkingDirectory = $PWD,
        [string]$TargetPlatform = "linux/amd64",
        [string] $BaseImagesAcrName =$null
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:DockerCacheFilePath=$DockerCacheFilePath"
        Write-Debug "${functionName}:TagName=$TagName"
        Write-Debug "${functionName}:AcrName=$AcrName"
        Write-Debug "${functionName}:DockerFileName=$DockerFileName"
        Write-Debug "${functionName}:WorkingDirectory=$WorkingDirectory"
        Write-Debug "${functionName}:TargetPlatform=$TargetPlatform"
        Write-Debug "${functionName}:BaseImagesAcrName=$BaseImagesAcrName"
    }
    process {
        try {
            Push-Location -Path $WorkingDirectory

            # Build the image using ACR if ACR name is provided, if not use local docker build
            if ("" -ne $AcrName) {
                Invoke-CommandLine -Command "az acr login --name $AcrName"
                Invoke-CommandLine -Command "az acr build -t $TagName -r $AcrName -f $DockerFileName ."
                Invoke-CommandLine -Command "docker pull $AcrName.azurecr.io/$TagName"
                Invoke-CommandLine -Command "docker tag $AcrName.azurecr.io/$TagName $TagName"
                Invoke-CommandLine -Command "az acr repository delete --name $AcrName --image $TagName --yes"            
            }
            else {
                if(-not [string]::IsNullOrEmpty($BaseImagesAcrName.Trim())){
                    Invoke-CommandLine -Command "az acr login --name $($BaseImagesAcrName.Trim().ToLower())"
                }
                Invoke-CommandLine -Command "docker buildx build -f $DockerFileName -t $TagName --platform=$TargetPlatform ."
            }
            # Save the image for future jobs
            Invoke-CommandLine -Command "docker save -o $DockerCacheFilePath $TagName"   

        }
        finally {
            Pop-Location
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
        [string]$WorkingDirectory = $PWD,
        [string]$TargetPlatform = "linux/amd64",
        [string] $BaseImagesAcrName =$null
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:DockerCacheFilePath=$DockerCacheFilePath"
        Write-Debug "${functionName}:TagName=$TagName"
        Write-Debug "${functionName}:AcrName=$AcrName"
        Write-Debug "${functionName}:AcrTagName=$AcrTagName"
        Write-Debug "${functionName}:DockerFileName=$DockerFileName"
        Write-Debug "${functionName}:WorkingDirectory=$WorkingDirectory"
        Write-Debug "${functionName}:TargetPlatform=$TargetPlatform"
        Write-Debug "${functionName}:BaseImagesAcrName=$BaseImagesAcrName"
    }
    process {

        try {
            
            Push-Location   -Path $WorkingDirectory
            # Load image if exists in cache
            if (Test-Path $DockerCacheFilePath -PathType Leaf) {
                Invoke-CommandLine -Command "docker load -i $DockerCacheFilePath"        
            }
            else {
                if(-not [string]::IsNullOrEmpty($BaseImagesAcrName.Trim())){
                    Invoke-CommandLine -Command "az acr login --name $($BaseImagesAcrName.Trim().ToLower())"
                }
                Invoke-CommandLine -Command "docker buildx build -f $DockerFileName -t $TagName --platform=$TargetPlatform ."  
                Invoke-CommandLine -Command "docker save -o $DockerCacheFilePath $TagName"          
            }
            Invoke-CommandLine -Command "az acr login --name $AcrName"
            Invoke-CommandLine -Command "docker tag $TagName $AcrTagName"          
            Invoke-CommandLine -Command "docker push $AcrTagName"   

        }
        finally {
            Pop-Location
        }

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
        [string]$WorkingDirectory = $PWD,
        [string]$TargetPlatform = "linux/amd64"
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:DockerCacheFilePath=$DockerCacheFilePath"
        Write-Debug "${functionName}:TagName=$TagName"
        Write-Debug "${functionName}:AcrName=$AcrName"
        Write-Debug "${functionName}:AcrTagName=$AcrTagName"
        Write-Debug "${functionName}:DockerFileName=$DockerFileName"
        Write-Debug "${functionName}:WorkingDirectory=$WorkingDirectory"
        Write-Debug "${functionName}:TargetPlatform=$TargetPlatform"
    }
    process {
        try {
            Push-Location -Path $WorkingDirectory
            Invoke-CommandLine -Command "docker buildx build -f $DockerFileName -t $TagName --platform=$TargetPlatform ."
            Invoke-CommandLine -Command "docker save -o $DockerCacheFilePath $TagName"
            Invoke-CommandLine -Command "az acr login --name $AcrName"
            Invoke-CommandLine -Command "docker tag $TagName $AcrTagName"  
            Invoke-CommandLine -Command "docker push $AcrTagName"    
        }
        finally {
            Pop-Location
        }
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Update-DockerfileVariables {
    param(
        [Parameter(Mandatory)]
        [string]$DockerFileName,
        [Parameter(Mandatory)]
        [hashtable]$Variables
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:DockerFileName=$DockerFileName"
    }
    process {
        Write-Debug "${functionName}:Updating Dockerfile $DockerFileName"
        if($Variables){
            
            $dockerFileContent = Get-Content -Path $DockerFileName -Raw

            foreach ($key in $Variables.Keys) {
                $placeholder = "{{" + $key + "}}"
                Write-Debug "${functionName}:Replacing $placeholder with $($Variables[$key])"
                $dockerFileContent = $dockerFileContent.Replace($placeholder, $Variables[$key])
            }
            
            Set-Content -Path $DockerFileName -Value $dockerFileContent -Force
            Write-Debug "${functionName}:Updated Dockerfile $DockerFileName"
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
Write-Debug "${functionName}:AcrRepoName=$AcrRepoName"
Write-Debug "${functionName}:ImageVersion=$ImageVersion"
Write-Debug "${functionName}:ImageCachePath=$ImageCachePath"
Write-Debug "${functionName}:Command=$Command"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Debug "${functionName}:DockerFilePath=$DockerFilePath"
Write-Debug "${functionName}:WorkingDirectory=$WorkingDirectory"
Write-Debug "${functionName}:TargetPlatform=$TargetPlatform"
Write-Debug "${functionName}:BaseImagesAcrName=$BaseImagesAcrName"

try {
    Import-Module $PSHelperDirectory -Force

    #Application Image
    [string]$AcrName = $AcrName.ToLower()
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
        Invoke-DockerBuild -DockerCacheFilePath $dockerCacheFilePath `
                           -TagName $tagName -AcrName $AcrName `
                           -DockerFileName $DockerFilePath -WorkingDirectory $WorkingDirectory `
                           -TargetPlatform $TargetPlatform `
                           -BaseImagesAcrName $BaseImagesAcrName
    }
    elseif ( $Command.ToLower() -eq 'push' ) {
        Invoke-DockerPush -DockerCacheFilePath $dockerCacheFilePath `
                          -TagName $tagName -AcrName $AcrName -AcrTagName $AcrtagName `
                          -DockerFileName $DockerFilePath -WorkingDirectory $WorkingDirectory `
                          -TargetPlatform $TargetPlatform `
                          -BaseImagesAcrName $BaseImagesAcrName
    }
    else {
        Invoke-DockerBuildAndPush -DockerCacheFilePath $dockerCacheFilePath `
                                  -TagName $tagName -AcrName $AcrName -AcrTagName $AcrtagName `
                                  -DockerFileName $DockerFilePath -WorkingDirectory $WorkingDirectory `
                                  -TargetPlatform $TargetPlatform    
    }    
    if ($LastExitCode -ne 0) {
        Write-Host "##vso[task.complete result=Failed;]DONE"
        $exitCode = -2
    }

    #DB Migration Image
    [string]$dbMigrationDockerFileName = "db-migration.Dockerfile"
    if (Test-Path $dbMigrationDockerFileName -PathType Leaf) {

        Write-Host "Processing DB Migration Docker file: $dbMigrationDockerFileName"
        Update-DockerfileVariables -DockerFileName $dbMigrationDockerFileName -Variables @{adpSharedAcrName = $BaseImagesAcrName}

        [string]$dbMigrationTagName = $AcrRepoName + "-dbmigration:" + $ImageVersion
        [string]$AcrDbMigrationTagName = $AcrName + ".azurecr.io/image/" + $dbMigrationTagName
        Write-Debug "${functionName}:DB Migration Docker Image=$dbMigrationTagName"
        Write-Debug "${functionName}:AcrDbMigrationTagName=$AcrDbMigrationTagName"
    
        [string]$dbDockerCacheFilePath = $ImageCachePath + "/db-cache.tar"
        if (!(Test-Path $ImageCachePath -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $ImageCachePath
        }
        
        if ( $Command.ToLower() -eq 'build' ) {
            Invoke-DockerBuild -DockerCacheFilePath $dbDockerCacheFilePath `
                               -TagName $dbMigrationTagName -AcrName $AcrName `
                               -DockerFileName $dbMigrationDockerFileName  -WorkingDirectory $WorkingDirectory `
                               -BaseImagesAcrName $BaseImagesAcrName
        }
        elseif ( $Command.ToLower() -eq 'push' ) {
            Invoke-DockerPush -DockerCacheFilePath $dbDockerCacheFilePath `
                              -TagName $dbMigrationTagName -AcrName $AcrName -AcrTagName $AcrDbMigrationTagName `
                              -DockerFileName $dbMigrationDockerFileName -WorkingDirectory $WorkingDirectory `
                              -BaseImagesAcrName $BaseImagesAcrName
        }
        else {
            Invoke-DockerBuildAndPush -DockerCacheFilePath $dbDockerCacheFilePath `
                                      -TagName $dbMigrationTagName -AcrName $AcrName -AcrTagName $AcrDbMigrationTagName `
                                      -DockerFileName $dbMigrationDockerFileName -WorkingDirectory $WorkingDirectory `
                                      -BaseImagesAcrName $BaseImagesAcrName
        }    
        if ($LastExitCode -ne 0) {
            Write-Host "##vso[task.complete result=Failed;]DONE"
            $exitCode = -2
        }  
    } 
    else {
        Write-Host "No DB Migration Docker file exist."
    }


    #AI Search Deploy Image
    [string]$aiSearchDockerFileName = "ai-search.Dockerfile"
    if (Test-Path $aiSearchDockerFileName -PathType Leaf) {

        Write-Host "Processing AI Search Docker file: $aiSearchDockerFileName"
        Update-DockerfileVariables -DockerFileName $aiSearchDockerFileName -Variables @{adpSharedAcrName = $BaseImagesAcrName }

        [string]$aiSearchTagName = $AcrRepoName + "-aisearch:" + $ImageVersion
        [string]$AcrAISearchTagName = $AcrName + ".azurecr.io/image/" + $aiSearchTagName
        Write-Debug "${functionName}:AI Search Docker Image=$aiSearchTagName"
        Write-Debug "${functionName}:AcrAISearchTagName=$AcrAISearchTagName"
    
        [string]$searchDockerCacheFilePath = $ImageCachePath + "/search-cache.tar"
        if (!(Test-Path $ImageCachePath -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $ImageCachePath
        }
        
        if ( $Command.ToLower() -eq 'build' ) {
            Invoke-DockerBuild -DockerCacheFilePath $searchDockerCacheFilePath `
                -TagName $aiSearchTagName -AcrName $AcrName `
                -DockerFileName $aiSearchDockerFileName  -WorkingDirectory $WorkingDirectory `
                -BaseImagesAcrName $BaseImagesAcrName
        }
        elseif ( $Command.ToLower() -eq 'push' ) {
            Invoke-DockerPush -DockerCacheFilePath $searchDockerCacheFilePath `
                -TagName $aiSearchTagName -AcrName $AcrName -AcrTagName $AcrAISearchTagName `
                -DockerFileName $aiSearchDockerFileName -WorkingDirectory $WorkingDirectory `
                -BaseImagesAcrName $BaseImagesAcrName
        }
        else {
            Invoke-DockerBuildAndPush -DockerCacheFilePath $searchDockerCacheFilePath `
                -TagName $aiSearchTagName -AcrName $AcrName -AcrTagName $AcrAISearchTagName `
                -DockerFileName $aiSearchDockerFileName -WorkingDirectory $WorkingDirectory `
                -BaseImagesAcrName $BaseImagesAcrName
        }    
        if ($LastExitCode -ne 0) {
            Write-Host "##vso[task.complete result=Failed;]DONE"
            $exitCode = -2
        }  
    } 
    else {
        Write-Host "No AI Search Docker file exist."
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
