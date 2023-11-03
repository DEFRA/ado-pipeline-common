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
.PARAMETER KeyVault
Mandatory. Application Keyvault
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\ImportYamlAppConfig.ps1 -AppConfig <AppConfig> -ServiceName <ServiceName> -ConfigFilePath <ConfigFilePath> -KeyVault <KeyVault> -PSHelperDirectory <PSHelperDirectory>
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
    [string] $KeyVault,
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
Write-Debug "${functionName}:KeyVault=$KeyVault"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force

    Install-Module powershell-yaml -Force
    Import-Module powershell-yaml -Force

    [string]$endpoint = "https://" + $AppConfig + ".azconfig.io" 
    $ConfigFileContent = Get-Content -Raw -Path $ConfigFilePath | ConvertFrom-YAML
    foreach ($item in $ConfigFileContent) {
        [string]$key = $item.key
        Write-Debug "${functionName}:$key" 
        if ($item.ContainsKey("type") -and $item.type -eq "keyvault" ) {
            [string]$keyVaultRef = "https://" + $KeyVault + ".vault.azure.net/Secrets/" + $item.value            
            Invoke-CommandLine -Command "az appconfig kv set-keyvault --endpoint $endpoint --auth-mode login --key $key --secret-identifier $keyVaultRef  --label $ServiceName --yes"
        }
        else {
            Invoke-CommandLine -Command "az appconfig kv set --endpoint $endpoint --auth-mode login --key $key --value $item.value  --label $ServiceName --yes"
        }
    }

    Write-Host "Get the keys from AppConfig $AppConfig"        
    $keysInAppConfig = Invoke-CommandLine -Command "az appconfig kv list --endpoint $endpoint --auth-mode login --label $ServiceName --fields key | ConvertFrom-Json"
    
    $keysInConfigFile = $ConfigFileContent | Foreach { $_.key }
    foreach ($key in $keysInAppConfig.key) {
        if ($keysInConfigFile -Contains $key ) {
            Write-Host $key 
        }
        else { 
            Write-Host "Key Does not exist in the config file - Deleting $key" 
            Invoke-CommandLine -Command "az appconfig kv delete --endpoint $endpoint --auth-mode login --key $key --label $ServiceName --yes" > $null
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