<#
.SYNOPSIS
Creates 'keyvault-secrets-role-assignment.yaml' template in Application's Infra Helm chart.
.DESCRIPTION
Adds keyvault-secrets-role-assignment.yaml template to Infra Helm chart folder and Appends required Keyvault secretname values  to values.yaml file.

.PARAMETER KeyVaultVSecretNames
Mandatory. Keyvault Secret Names in string format
.PARAMETER InfraChartHomeDir
Mandatory. Directory Path of Infra Chart HomeDirectory
.PARAMETER ServiceName
Mandatory. Service Name
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\Build-Helm-KVSecretsRoleAssignments.ps1 -KeyVaultVSecretNames <KeyVaultVSecretNames> -InfraChartHomeDir <InfraChartHomeDir> -ServiceName <ServiceName> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $KeyVaultVSecretNames,
    [Parameter(Mandatory)]
    [string] $InfraChartHomeDir,
    [Parameter(Mandatory)]
    [string]$ServiceName,
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
Write-Debug "${functionName}:KeyVaultVSecretNames=$KeyVaultVSecretNames"
Write-Debug "${functionName}:InfraChartHomeDir=$InfraChartHomeDir"
Write-Debug "${functionName}:ServiceName=$ServiceName"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {
    if (Test-Path "$($InfraChartHomeDir)\templates") {
        if (!([string]::IsNullOrEmpty($KeyVaultVSecretNames)) -and ($KeyVaultVSecretNames -ne "null")) {
            Import-Module $PSHelperDirectory -Force

            if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
                Write-Host "powershell-yaml Module does not exists. Installing now.."
                Install-Module powershell-yaml -Force
                Write-Host "powershell-yaml Installed Successfully."
            } 
            else {
                Write-Host "powershell-yaml Module exist"
            }

            $kvSecretNames = $KeyVaultVSecretNames | ConvertFrom-Json

            Write-Debug "${functionName}:kvSecretNames:$kvSecretNames"
    
            $valuesYamlPath = "$InfraChartHomeDir\values.yaml"
            [string]$content = Get-Content -Raw -Path $valuesYamlPath
            Write-Debug "$valuesYamlPath content before: $content"
            if($content) {
                $valuesObject = ConvertFrom-YAML $content -Ordered
                # This condition is to initialize '$valuesObject' when values.yaml files contains only comments and not any values(Possible scenario).
                if(-not $valuesObject) {
                    $valuesObject = [ordered]@{}
                }
            }
            else {
                $valuesObject = [ordered]@{}
            }

            $keyVaultSecrets = [System.Collections.Generic.List[hashtable]]@()
            foreach ($secret in $kvSecretNames) {
                
                #Logic to remove servicename from the secretname
                #for e.g. "ffc-demo-payment-web-COOKIE-PASSWORD" will get replace with "COOKIE-PASSWORD"
                if($secret -like "$ServiceName*"){
                    $NoOfStartingCharsToTrunk = $ServiceName.Length + 1
                    $secretWithoutServiceName = $secret.subString($NoOfStartingCharsToTrunk, ($secret.Length - $NoOfStartingCharsToTrunk) )
                }
                else {
                    $secretWithoutServiceName = $secret
                }

                $roleAssignments = [System.Collections.Generic.List[hashtable]]@()
                $roleAssignments.Add(@{
                        roleName = "keyvaultsecretuser"
                    })

                $keyVaultSecrets.Add(@{
                        name            = $secretWithoutServiceName
                        roleAssignments = $roleAssignments
                    })
            }

            $valuesObject.Add("keyVaultSecrets", $keyVaultSecrets)

            Write-Host "Converting valuesObject to yaml and writing it to file : $valuesYamlPath"
            $output = Convertto-yaml $valuesObject
            Write-Debug "$valuesYamlPath content after: $output"
            $output | Out-File $valuesYamlPath

            Write-Host "Adding 'keyvault-secrets-role-assignment.yaml' file to $InfraChartHomeDir\templates folder"
            '{{- include "adp-aso-helm-library.keyvault-secrets-role-assignment" . -}}' | Out-File -FilePath "$InfraChartHomeDir\templates\keyvault-secrets-role-assignment.yaml"
        }
        else {
            Write-Host "KeyVaultVSecretNames are empty. Skipped creation of Keyvault roleassignments"
        }
    }
    else {
        Write-Host "Helm Infra chart path '$InfraChartHomeDir\templates' does not exit. Skipped creation of Keyvault roleassignments"
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