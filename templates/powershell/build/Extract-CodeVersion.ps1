<#
.SYNOPSIS
Extract code version based on the framework type
.DESCRIPTION
Extract code version based on the framework type
.PARAMETER AppFrameworkType
Mandatory. Application Framework Type. dotnet or nodejs
.PARAMETER ProjectPath
Mandatory. relative project file path. For DotNet csproj file path, For NodeJS path of package.json

.EXAMPLE
.\Extract-CodeVersion.ps1  -AppFrameworkType <AppFrameworkType> -ProjectPath <ProjectPath> 
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AppFrameworkType,
    [Parameter(Mandatory)]
    [string] $ProjectPath
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

try {
    $appVersion = ""
    $oldAppVersion = "0.0.0"
    $exitCode = 0
    $defaultBranchName = "master"
    try {

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
    catch {
        Write-Debug "Error reading branch "
        $exitCode = -2
    }
 

    if ( $AppFrameworkType.ToLower() -eq 'dotnet' ) {
        $xml = [Xml] (Get-Content $ProjectPath )
        $appVersion = $xml.Project.PropertyGroup.Version
        
        try {
            git fetch --all
            git checkout -b devops origin/$defaultBranchName
                
            $xml = [Xml] (Get-Content $ProjectPath )
            $oldAppVersion = $xml.Project.PropertyGroup.Version
        }
        catch {
            Write-Debug "Error switching branch "
            $exitCode = -2
        }
        
    }
    elseif ( $AppFrameworkType.ToLower() -eq 'nodejs' ) {
        $appVersion = node -p "require('$ProjectPath').version"   

        try {
            git fetch --all
            git checkout -b devops origin/$defaultBranchName
        
            $oldAppVersion = node -p "require('$ProjectPath').version" 
        }
        catch {
             Write-Debug "Error switching branch "
             $exitCode = -2
        }             
    }
    else {        
        $exitCode = -2
    }

    if (([version]$appVersion).CompareTo(([version]$oldAppVersion)) -gt 0) {
        Write-Output "${functionName}:appVersion updated"    
    }
    else {
        Write-Output "${functionName}:appVersion not updated"    
        $exitCode = -2
    }

    Write-Debug "${functionName}:appVersion=$appVersion;oldAppVersion=$oldAppVersion"    
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