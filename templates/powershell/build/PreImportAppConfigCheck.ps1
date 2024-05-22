<#
.SYNOPSIS
    This script performs pre-import checks for application configuration.

.DESCRIPTION
    The script checks if the secrets in the application configuration file exist in the specified Key Vault and if the service has the necessary role assignments to access these secrets. 
    It uses the Azure PowerShell module to interact with Azure resources.

.PARAMETER AdoVariableNames
    A JSON string containing the names of Azure DevOps variables.

.PARAMETER SubscriptionId
    The ID of the Azure subscription.

.PARAMETER ServiceName
    The name of the service.

.PARAMETER ConfigFilePath
    The path to the application configuration file.

.PARAMETER KeyVaultName
    The name of the Key Vault.

.PARAMETER PSHelperDirectory
    The directory containing the PowerShell helper scripts.

.PARAMETER AppConfigModuleDirectory
    The directory containing the application configuration module.

.FUNCTION Test-AppConfigSecretValue
    This function checks if a secret exists in the Key Vault and if the service has the necessary role assignments to access it.
#>

[CmdletBinding()]
param(
    [string]$AdoVariableNames = "[]",
    [Parameter(Mandatory)]
    [string] $SubscriptionId,
    [Parameter(Mandatory)]
    [string] $ServiceName,
    [Parameter(Mandatory)]
    [string] $ConfigFilePath,
    [Parameter(Mandatory)]
    [string] $KeyVaultName,
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [Parameter(Mandatory)]
    [string]$AppConfigModuleDirectory
)

function Test-AppConfigSecretValue{
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AppConfigEntry]$ConfigSecret,
        [string]$KeyVaultName,
        [string]$ServiceName,
        [string]$AdoVariableNames = "[]"
    )

    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:KeyVaultName:$KeyVaultName"
        Write-Debug "${functionName}:ServiceName:$ServiceName"
        Write-Debug "${functionName}:AdoVariableNames:$AdoVariableNames"
        $keyVaultResourceId = (Get-AzKeyVault -VaultName $KeyVaultName).ResourceId
        $adoVariableNamesList = $AdoVariableNames | ConvertFrom-Json
    }
    
    process {
        Write-Debug "${functionName}:ConfigSecret:$ConfigSecret"
        $secretName = $ConfigSecret.GetSecretName()
        Write-Debug "${functionName}:secretName:$secretName"

        if ($adoVariableNamesList -contains $secretName) {
            Write-Debug "${functionName}:secretName:$secretName is in the list of ADO variables"
            return
        }

        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName
        if ($secret) {
            $scope = "{0}/secrets/{1}" -f $keyVaultResourceId, $secretName
            Write-Debug "${functionName}:Key Vault Secret Scope:$scope"

            Write-Debug "${functionName}:Checking role assignment for the secret $secretName in the Key Vault $KeyVaultName for the service $ServiceName"
            $role = Get-AzRoleAssignment -Scope $scope -RoleDefinitionName 'Key Vault Secrets User' | Where-Object { $_.DisplayName -like '*'+$ServiceName }
            if (!$role) {
                $warningObject = New-Object PSObject -Property @{ 
                    Type = "warning" 
                    Message = "Role assignment for the secret $secretName in the Key Vault $KeyVaultName does not exist. The application $ServiceName will not function correctly without this role." 
                }
                Write-Output $warningObject
            }
        } 
        else {
            $errorObject = New-Object PSObject -Property @{ 
                Type = "error" 
                Message = "Secret $secretName not found in the Key Vault $KeyVaultName." 
            }
            Write-Output $errorObject
        }
    }
    
    end {
        Write-Debug "${functionName}: Exited"
    }
}

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
Write-Debug "${functionName}:AdoVariableNames=$AdoVariableNames"
Write-Debug "${functionName}:SubscriptionId=$SubscriptionId"
Write-Debug "${functionName}:ServiceName=$ServiceName"
Write-Debug "${functionName}:ConfigFilePath=$ConfigFilePath"
Write-Debug "${functionName}:KeyVaultName=$KeyVaultName"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Debug "${functionName}:AppConfigModuleDirectory=$AppConfigModuleDirectory"

try {
    Import-Module $PSHelperDirectory -Force
    Import-Module $AppConfigModuleDirectory -Force

    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null

    if (Test-Path $ConfigFilePath -PathType Leaf) {

        Write-Debug "${functionName}:ConfigFilePath exists"
        [AppConfigEntry[]]$configItems = Get-AppConfigValuesFromYamlFile -Path $ConfigFilePath -DefaultLabel $ServiceName -KeyVault $KeyVaultName 
        Write-Debug "${functionName}:ConfigItems=$configItems"

        $issues = $configItems | Where-Object { 
            $_.IsKeyVault() 
        } | Test-AppConfigSecretValue -KeyVaultName $KeyVaultName -ServiceName $ServiceName -AdoVariableNames $AdoVariableNames

        if($issues) {
            $issues | ForEach-Object {
                $propertyNames = $_.PSObject.Properties.Name
                if ($propertyNames -contains 'Type' -and $propertyNames -contains 'Message') {
                    Write-Host "##vso[task.logissue type=$($_.Type)]$($_.Message)"
                }
            }
            if ($issues | Where-Object { $_.Type -eq 'error' }) {
                throw "Import validation failed for the secrets in the app config file."
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