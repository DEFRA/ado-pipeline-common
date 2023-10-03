<#
.SYNOPSIS
Extract code version based on the framework type
.DESCRIPTION
Extract code version based on the framework type
.PARAMETER AppFrameworkType
Mandatory. Application Framework Type. dotnet or nodejs
.PARAMETER ProjectPath
Mandatory. relative project file path. For DotNet csproj file path, For NodeJS path of package.json
.PARAMETER DefaultBranchName
Optional. Default Branch. master or main
.PARAMETER IsMainBranchBuild
Mandatory. True if the build triggered for main branch, else false.

.EXAMPLE
.\Extract-CodeVersion.ps1  -AppFrameworkType <AppFrameworkType> -ProjectPath <ProjectPath> -DefaultBranchName <DefaultBranchName> -IsMainBranchBuild <IsMainBranchBuild>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AppFrameworkType,
    [Parameter(Mandatory)]
    [string] $ProjectPath,
    [string] $DefaultBranchName = "",
    [Parameter(Mandatory)]
    [string] $IsMainBranchBuild
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
Write-Debug "${functionName}:AppFrameworkType=$AppFrameworkType"
Write-Debug "${functionName}:ProjectPath=$ProjectPath"
Write-Debug "${functionName}:DefaultBranchName=$DefaultBranchName"
Write-Debug "${functionName}:IsMainBranchBuild=$IsMainBranchBuild"

try {
    $appVersion = ""
    #Assume version 0.0.0 for initial main branch
    $oldAppVersion = "0.0.0"
    $exitCode = 0
    $versionFilePath = "./VERSION"
    $IsMainBranchBuild = [System.Convert]::ToBoolean($IsMainBranchBuild)
    try {
        git fetch origin
        if ("" -eq $DefaultBranchName) {
            $masterBranchExists = git ls-remote --heads origin master
            if ($null -eq $masterBranchExists) {
                $mainBranchExists = git ls-remote --heads origin main
                if ($null -eq $mainBranchExists) {
                    $exitCode = -2
                }
                else {
                    $defaultBranchName = "main"
                }
            }
        }
    }
    catch {
        Write-Debug "Error reading branch "
        $exitCode = -2
    }
    #If custom VERSION file exists, read version number from file
    if (Test-Path $versionFilePath -PathType Leaf) {
        $appVersion = (Get-Content $versionFilePath).Trim()
        if (!$IsMainBranchBuild) {
            git checkout -b devops origin/$defaultBranchName
            if (Test-Path $versionFilePath -PathType Leaf) {
                $oldAppVersion = (Get-Content $versionFilePath).Trim()
            }
        }
    }
    elseif ( $AppFrameworkType.ToLower() -eq 'dotnet' ) {
        $xml = [Xml] (Get-Content $ProjectPath )
        $appVersion = $xml.Project.PropertyGroup.Version
        if (!$IsMainBranchBuild) {      
            git checkout -b devops origin/$defaultBranchName
            if (Test-Path $ProjectPath -PathType Leaf) {
                $xml = [Xml] (Get-Content $ProjectPath )
                $oldAppVersion = $xml.Project.PropertyGroup.Version
            }   
        }     
    }
    elseif ( $AppFrameworkType.ToLower() -eq 'nodejs' ) {
        $appVersion = node -p "require('$ProjectPath').version"
        if (!$IsMainBranchBuild) {
            git checkout -b devops origin/$defaultBranchName
            if (Test-Path $ProjectPath -PathType Leaf) {
                $oldAppVersion = node -p "require('$ProjectPath').version" 
            }        
        } 
    }
    else {
        Write-Debug "${functionName}: Error identifying version"     
        $exitCode = -2
    }

    if (!$IsMainBranchBuild) {
        #Check if the version is upgraded
        if (([version]$appVersion).CompareTo(([version]$oldAppVersion)) -gt 0) {
            Write-Output "${functionName}:appVersion upgraded"    
        }
        else {
            Write-Output "${functionName}:appVersion not upgraded"    
            $exitCode = -2
        }
    }

    Write-Output "${functionName}:appVersion=$appVersion;oldAppVersion=$oldAppVersion"    
    Write-Output "##vso[task.setvariable variable=appVersion;isOutput=true]$appVersion"
    Write-Output "##vso[task.setvariable variable=oldAppVersion;isOutput=true]$oldAppVersion"
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