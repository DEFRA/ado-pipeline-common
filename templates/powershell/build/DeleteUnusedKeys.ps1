<#
.SYNOPSIS
Delete key-values that are not included in the configuration file
.DESCRIPTION
Delete key-values that are not included in the configuration file

.PARAMETER AppConfig
Mandatory. Azure Application Configuration
.PARAMETER ServiceName
Mandatory. ServiceName
.PARAMETER ConfigFilePath
Mandatory. App Config file path. 
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\DeleteUnusedKeys.ps1 -AppConfig <AppConfig> -ServiceName <ServiceName>  -ConfigFilePath <ConfigFilePath> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $AppConfig,
    [Parameter(Mandatory)]
    [string] $ServiceName,
    [Parameter(Mandatory)]
    [string] $ConfigFilePath,
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
Write-Debug "${functionName}:AppConfig=$AppConfig"
Write-Debug "${functionName}:ServiceName=$ServiceName"
Write-Debug "${functionName}:ConfigFilePath=$ConfigFilePath"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force

    Write-Host "Get the keys from AppConfig $AppConfig"        
    $keysInAppConfig = Invoke-CommandLine -Command "az appconfig kv list --endpoint https://$AppConfig.azconfig.io --auth-mode login --label $ServiceName --fields key | ConvertFrom-Json"
    $ConfigFileContent = Get-Content -Raw -Path $ConfigFilePath | ConvertFrom-Json
    $keysInConfigFile = $ConfigFileContent | Foreach { $_.items } | Foreach { $_.key }
    foreach ($key in $keysInAppConfig.key) {
        if ($keysInConfigFile -Contains $key ) {
            Write-Host $key 
        }
        else { 
            Write-Host "Key Does not exist in the config file - Deleting $key" 
            Invoke-CommandLine -Command "az appconfig kv delete -n $AppConfig --key $key --label $ServiceName --yes" > $null
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
}