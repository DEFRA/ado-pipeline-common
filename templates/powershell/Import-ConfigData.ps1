[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AppConfigName,
    [Parameter(Mandatory)]
    [string] $Label,
    [string] $ConfigDataFilePath,
    [array] $ConfigData,
    [string]$WorkingDirectory = $PWD,
    [switch]$DeleteEntriesNotInFile
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
Write-Debug "${functionName}:AppConfigName=$AppConfigName"
Write-Debug "${functionName}:Label=$Label"
Write-Debug "${functionName}:ConfigDataFilePath=$ConfigDataFilePath"
Write-Debug "${functionName}:ConfigData=$ConfigData"
Write-Debug "${functionName}:WorkingDirectory=$WorkingDirectory"

try {
    if ($null -eq $ConfigData -and $null -eq $ConfigDataFilePath) {
        throw "One of the parameters 'ConfigData' or 'ConfigDataFilePath' is required."
    }

    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $WorkingDirectory -ChildPath "templates/powershell/modules/ps-helpers"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
    Import-Module $moduleDir.FullName -Force

    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $WorkingDirectory -ChildPath "templates/powershell/modules/app-config"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
    Import-Module $moduleDir.FullName -Force

    if ($ConfigData) {
        $ConfigDataFilePath = Join-Path -Path $WorkingDirectory -ChildPath "$AppConfigName-$Label.json"
        $ConfigData | Out-File -FilePath $ConfigDataFilePath
    }
    
    if ($DeleteEntriesNotInFile) {
        Import-AppConfigValues -Path $ConfigDataFilePath -ConfigStore $AppConfigName -Label $Label -DeleteEntriesNotInFile
    }
    else {
        Import-AppConfigValues -Path $ConfigDataFilePath -ConfigStore $AppConfigName -Label $Label
    }

    Invoke-CommandLine -Command "az logout" -NoOutput

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
