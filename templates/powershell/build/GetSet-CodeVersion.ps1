<#
.SYNOPSIS
Get or Set code version to ArtifactFilePath
.DESCRIPTION
Get or Set code version to ArtifactFilePath
.PARAMETER Command
Mandatory. Command to execute Get or Set
.PARAMETER AppVersion
Mandatory. AppVersion to Set
.PARAMETER ArtifactFilePath
Optional. If provided extract the version from the artifact file. This is used in deployment steps
.EXAMPLE
.\GetSet-CodeVersion.ps1  -Command <Command> -AppVersion <AppVersion> -ArtifactFilePath <ArtifactFilePath>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Command,
    [string] $AppVersion = "",
    [string] $ArtifactFilePath = "."
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
Write-Debug "${functionName}:Command=$Command"
Write-Debug "${functionName}:ArtifactFilePath=$ArtifactFilePath"

try {
    
    $exitCode = 0

    if ( $Command.ToLower() -eq 'set' ) {
        if (!(Test-Path $ArtifactFilePath -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $ArtifactFilePath
        }

        $AppVersion | Out-File -FilePath $ArtifactFilePath/appversion.txt    
    }
    elseif ( $Command.ToLower() -eq 'get' ) {
        if (Test-Path $ArtifactFilePath/appversion.txt -PathType Leaf) {
            $AppVersion = Get-Content $ArtifactFilePath/appversion.txt;  
            Write-Output "##vso[task.setvariable variable=appVersion;isOutput=true]$AppVersion"
        }
        else {
            $AppVersion = ""
            $exitCode = -2
        }
    }
    else {
        $AppVersion = ""
        $exitCode = -2
    }    
    Write-Debug "${functionName}:appVersion=$AppVersion"        
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