<#
.SYNOPSIS
Extract code version based on the framework type
.DESCRIPTION
Extract code version based on the framework type
.PARAMETER AppFrameworkType
Mandatory. Application Framework Type. dotnet or nodejs
.PARAMETER ProjectPath
Mandatory. relative project file path. For DotNet csproj file path, For NodeJS path of package.json and for helm chart path of Chart.yaml
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module

.EXAMPLE
.\Extract-CodeVersion.ps1  -AppFrameworkType <AppFrameworkType> -ProjectPath <ProjectPath> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AppFrameworkType,
    [Parameter(Mandatory)]
    [string] $ProjectPath,
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory
)

Set-StrictMode -Version 3.0

function Test-SemVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0,
            HelpMessage = "Specifies the version to test.")]
        [String]$Version
    )
    $regexPattern = '^(?<major>\d*)?(?:\.(?<minor>\d*))?(?:\.(?<patch>\d*))?(?:\.(?<build>\d*))$'
    $result = [Regex]::Match($Version, $regexPattern)
    return $result.Success
}

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
Write-Debug "${functionName}:AppFrameworkType=$AppFrameworkType"
Write-Debug "${functionName}:ProjectPath=$ProjectPath"
Write-Output "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {
    
    Import-Module $PSHelperDirectory -Force
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        Write-Host "powershell-yaml Module does not exists. Installing now.."
        Install-Module powershell-yaml -Force -Scope CurrentUser
        Write-Host "powershell-yaml Installed Successfully."
    } 
    else {
        Write-Host "powershell-yaml Module exist"
    }
    $appVersion = ""
    $oldAppVersion = "0.1.0" #Assume version 0.1.0 for initial main branch
    [bool]$isSymenticVersion = $true
    $exitCode = 0
    $versionFilePath = "./VERSION"
    $DefaultBranchName = Invoke-CommandLine -Command "git remote show origin | sed -n '/HEAD branch/s/.*: //p'"
    $IsDefaultBranchBuild = "False"
    $CurrentBranchName = (Get-ChildItem -Path Env:BUILD_SOURCEBRANCH).value
    if ($CurrentBranchName -like "refs/tags*") {
        $IsDefaultBranchBuild = "True"
    }
    elseif ($CurrentBranchName -eq ("refs/heads/" + $DefaultBranchName) ) {
        $IsDefaultBranchBuild = "True"
    }
    
    Invoke-CommandLine -Command "git fetch origin"        
    
    #If custom VERSION file exists, read version number from file
    if (Test-Path $versionFilePath -PathType Leaf) {
        $appVersion = (Get-Content $versionFilePath).Trim()
        if ( $IsDefaultBranchBuild -eq "False") {
            Invoke-CommandLine -Command "git checkout -b devops origin/$DefaultBranchName"
            if (Test-Path $versionFilePath -PathType Leaf) {
                $oldAppVersion = (Get-Content $versionFilePath).Trim()
            }
        }
    }
    elseif ( $AppFrameworkType.ToLower() -eq 'dotnet' ) {
        $xml = [Xml] (Get-Content $ProjectPath )
        if ($xml.Project.PropertyGroup.length -gt 1) {
            $appVersion = $xml.Project.PropertyGroup[0].Version
        }
        else {
            $appVersion = $xml.Project.PropertyGroup.Version
        }

        if ($IsDefaultBranchBuild -eq "False") {      
            Invoke-CommandLine -Command "git checkout -b devops origin/$DefaultBranchName"
            if (Test-Path $ProjectPath -PathType Leaf) {
                $xml = [Xml] (Get-Content $ProjectPath )
                try {
                    if ($xml.Project.PropertyGroup.length -gt 1) {
                        $oldAppVersion = $xml.Project.PropertyGroup[0].Version  
                    }
                    else {
                        $oldAppVersion = $xml.Project.PropertyGroup.Version
                    }
                }
                catch {  
                    $oldAppVersion = "0.1.0" #Assume version 0.1.0 for initial main branch when migrated
                }
                
            }   
        }     
    }
    elseif ( $AppFrameworkType.ToLower() -eq 'nodejs' ) {
        $appVersion = node -p "require('$ProjectPath').version"
        if ($IsDefaultBranchBuild -eq "False") {  
            Invoke-CommandLine -Command "git checkout -b devops origin/$DefaultBranchName"
            if (Test-Path $ProjectPath -PathType Leaf) {
                $oldAppVersion = node -p "require('$ProjectPath').version" 
            }        
        } 
    }
    elseif ( $AppFrameworkType.ToLower() -eq 'helm' ) {
        $appVersion = (Get-Content $ProjectPath | ConvertFrom-Yaml).version
        if ($IsDefaultBranchBuild -eq "False") {  
            Invoke-CommandLine -Command "git checkout -b devops origin/$DefaultBranchName"
            if (Test-Path $ProjectPath -PathType Leaf) {
                $oldAppVersion = (Get-Content $ProjectPath | ConvertFrom-Yaml).version
            }      
        } 
    }
    elseif ( $AppFrameworkType.ToLower() -eq 'java' ) {
        [xml]$app = Get-Content $ProjectPath
        $appVersion = $app.project.version
        if ($IsDefaultBranchBuild -eq "False") {  
            Invoke-CommandLine -Command "git checkout -b devops origin/$DefaultBranchName"
            if (Test-Path $ProjectPath -PathType Leaf) {
                [xml]$oldApp = Get-Content $ProjectPath
                $oldAppVersion = $oldApp.project.version
            }
            $isSymenticVersion = (Test-SemVersion -Version $appVersion) -and (Test-SemVersion -Version $oldAppVersion)
        }
    }
    else {
        Write-Debug "${functionName}: Error identifying version"     
        $exitCode = -2
    }
    $buildId = $Env:BUILD_BUILDID
    #For non default branch builds, check if the version is upgraded
    if ($IsDefaultBranchBuild -eq "False") {
        #$buildReason = $Env:BUILD_REASON # will be PullRequest for PR builds

        if ($isSymenticVersion -and ([version]$appVersion).CompareTo(([version]$oldAppVersion)) -gt 0) {
            Write-Output "${functionName}:Version increment valid '$oldAppVersion' -> '$appVersion'."
            #uppend alpha and build id to version for feature branches which will be deployed to snd env   e.g 4.32.33-alpha.506789
            $appVersion = "$appVersion-alpha.$buildId"   
            Write-Output "${functionName}: Build Version Tagged with alpha and build id :-> '$appVersion'." 
        }
        elseif ((-not $isSymenticVersion) -and $appVersion -gt $oldAppVersion) {
            Write-Output "${functionName}:Version increment valid '$oldAppVersion' -> '$appVersion'."
            #uppend alpha and build id to version for feature branches which will be deployed to snd env   e.g 4.32.33-alpha.506789
            $appVersion = "$appVersion-alpha.$buildId"
            Write-Output "${functionName}: Build Version Tagged with alpha and build id :-> '$appVersion'." 
        }
        else {
            Write-Output "${functionName}:Version increment invalid '$oldAppVersion' -> '$appVersion'. Please increment the version to run the CI process."
            Write-Host "##vso[task.logissue type=error]${functionName}:Version increment is invalid '$oldAppVersion' -> '$appVersion'. Please increment the version to run the CI process. Check logs for further details."
            $exitCode = -2
        }
    }

    Write-Output "${functionName}:IsDefaultBranchBuild=$IsDefaultBranchBuild;DefaultBranchName=$DefaultBranchName"
    Write-Output "${functionName}:CurrentBranchName=$CurrentBranchName;"    
    Write-Output "##vso[task.setvariable variable=appVersion;isOutput=true]$appVersion"
    Write-Output "##vso[task.setvariable variable=oldAppVersion;isOutput=true]$oldAppVersion"
    Write-Output "##vso[task.setvariable variable=IsDefaultBranchBuild;isOutput=true]$IsDefaultBranchBuild"
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
