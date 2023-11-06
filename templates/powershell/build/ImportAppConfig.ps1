<#
.SYNOPSIS
Import Key values from Yaml configuration file to Azure App Config
.DESCRIPTION
Import Key values from Yaml configuration file to Azure App Config

.PARAMETER AppConfig
Mandatory. Azure Application Configuration
.PARAMETER ServiceName
Mandatory. ServiceName
.PARAMETER ConfigFilePath
Mandatory. App Config file path. 
.PARAMETER SchemaFilePath
Mandatory. App Config Validation Schema file path. 
.PARAMETER KeyVault
Mandatory. Application Keyvault
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.PARAMETER AppConfigModuleDirectory
Mandatory. Directory Path of App-Config module
.EXAMPLE
.\ImportYamlAppConfig.ps1 -AppConfig <AppConfig> -ServiceName <ServiceName> -ConfigFilePath <ConfigFilePath> -SchemaFilePath <SchemaFilePath> -KeyVault <KeyVault> -PSHelperDirectory <PSHelperDirectory> -AppConfigModuleDirectory <AppConfigModuleDirectory>
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
    [string] $SchemaFilePath,
    [Parameter(Mandatory)]
    [string] $KeyVault,
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [Parameter(Mandatory)]
    [string]$AppConfigModuleDirectory
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
Write-Debug "${functionName}:SchemaFilePath=$SchemaFilePath"
Write-Debug "${functionName}:KeyVault=$KeyVault"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Debug "${functionName}:AppConfigModuleDirectory=$AppConfigModuleDirectory"

try {

    Import-Module $PSHelperDirectory -Force
    Import-Module $AppConfigModuleDirectory -Force

    if ($ConfigFilePath.EndsWith(".json")) {
        if (Test-Path $ConfigFilePath -PathType Leaf) {
            $json = Get-Content $ConfigFilePath -Raw | Out-String
        }
        
        if (($json | Test-Json -SchemaFile $SchemaFilePath) -eq $true) {
            Write-Host "${functionName} JSON File`t`tPassed validation"

            # If Valid - import config values
            Import-AppConfigValues -Path $ConfigFilePath -ConfigStore $AppConfig -Label $ServiceName -DeleteEntriesNotInFile
        }
        else {
            Write-Host "${functionName} JSON File`t`tFailed validation"
            throw [System.IO.InvalidDataException]::new($SchemaFilePath)
        }    
    }
    else {
        Import-AppConfigValues -Path $ConfigFilePath -ConfigStore $AppConfig -Label $ServiceName -DeleteEntriesNotInFile -KeyVaultName $KeyVault
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