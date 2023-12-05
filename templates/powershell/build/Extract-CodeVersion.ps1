<#
.SYNOPSIS
Extract code version based on the framework type
.DESCRIPTION
Extract code version based on the framework type
.PARAMETER AppFrameworkType
Mandatory. Application Framework Type. dotnet or nodejs
.PARAMETER ProjectPath
Mandatory. relative project file path. For DotNet csproj file path, For NodeJS path of package.json
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
Write-Output "##vso[task.setprogress value=0;]Code Version"

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
Write-Output "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {
    
    Import-Module $PSHelperDirectory -Force
    $appVersion = ""    
    $oldAppVersion = "0.0.0" #Assume version 0.0.0 for initial main branch
    $exitCode = 0
    $versionFilePath = "./VERSION"
    $DefaultBranchName = Invoke-CommandLine -Command "git remote show origin | sed -n '/HEAD branch/s/.*: //p'"
    $IsDefaultBranchBuild = "False"
    $CurrentBranchName=(Get-ChildItem -Path Env:BUILD_SOURCEBRANCH).value
    if ($CurrentBranchName -like "refs/tags*") {
        $IsDefaultBranchBuild = "True"
    }
    elseif ($CurrentBranchName -eq ("refs/heads/" + $DefaultBranchName) ) {
        $IsDefaultBranchBuild = "True"
    }
    
    Invoke-CommandLine -Command "git fetch origin"        
    Write-Output "##vso[task.setprogress value=10;]Code Version"
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
        $appVersion = $xml.Project.PropertyGroup.Version
        if ($IsDefaultBranchBuild -eq "False") {      
            Invoke-CommandLine -Command "git checkout -b devops origin/$DefaultBranchName"
            if (Test-Path $ProjectPath -PathType Leaf) {
                $xml = [Xml] (Get-Content $ProjectPath )
                $oldAppVersion = $xml.Project.PropertyGroup.Version
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
    else {
        Write-Debug "${functionName}: Error identifying version"     
        $exitCode = -2
    }
    Write-Output "##vso[task.setprogress value=90;]Code Version"
    if ($IsDefaultBranchBuild -eq "False") {
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
    Write-Output "${functionName}:IsDefaultBranchBuild=$IsDefaultBranchBuild;DefaultBranchName=$DefaultBranchName"    
    Write-Output "${functionName}:CurrentBranchName=$CurrentBranchName;"    
    Write-Output "##vso[task.setvariable variable=appVersion;isOutput=true]$appVersion"
    Write-Output "##vso[task.setvariable variable=oldAppVersion;isOutput=true]$oldAppVersion"
    Write-Output "##vso[task.setvariable variable=IsDefaultBranchBuild;isOutput=true]$IsDefaultBranchBuild"
    Write-Output "##vso[task.setprogress value=100;]Code Version"
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