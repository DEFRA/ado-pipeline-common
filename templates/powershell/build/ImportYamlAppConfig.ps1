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
    $keysInConfigFile = $ConfigFileContent | Foreach { $_.key }

    Write-Host "Get the keys from AppConfig $AppConfig"        
    $keysInAppConfig = Invoke-CommandLine -Command "az appconfig kv list --endpoint $endpoint --auth-mode login --label $ServiceName --fields key value | ConvertFrom-Json"
    $keyValueInAppConfig = @{}
    
    # If App Config Key not present in config file then delete the record
    foreach ($obj in $keysInAppConfig) {
        [string]$key = $obj.key 
        [string]$value = $obj.value 
        if ($keysInConfigFile -Contains $key ) {
            $keyValueInAppConfig.Add($key, $value)
        }
        else { 
            Write-Host "Key Does not exist in the config file - Deleting $key" 
            Invoke-CommandLine -Command "az appconfig kv delete --endpoint $endpoint --auth-mode login --key $key --label $ServiceName --yes" > $null
        }
    }

    foreach ($configFileObj in $ConfigFileContent) {
        # If App config value for a matching key is deferent in the config file then add or update key/value
        [string]$key = $configFileObj.key 
        [string]$value = $configFileObj.value 
        if ( $keyValueInAppConfig.Item($key) -ne $value  ) {

            if ($configFileObj.ContainsKey("type") -and $configFileObj.type -eq "keyvault" ) {
                [string]$keyVaultRef = "https://" + $KeyVault + ".vault.azure.net/Secrets/" + $value            
                Invoke-CommandLine -Command "az appconfig kv set-keyvault --endpoint $endpoint --auth-mode login --key $key --secret-identifier $keyVaultRef  --label $ServiceName --yes"
            }
            else {
                Invoke-CommandLine -Command "az appconfig kv set --endpoint $endpoint --auth-mode login --key $key --value $value  --label $ServiceName --yes"
            }
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