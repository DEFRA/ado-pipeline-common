[CmdletBinding()]
param(
    [string]$AdoVariableNames = "[]",
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
        
        Get-InstalledModule -Name Az.Resources
        Get-AzContext

        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName
        if ($secret) {
            $scope = "{0}/secrets/{1}" -f $keyVaultResourceId, $secretName
            Write-Host "${functionName}:Key Vault Secret Scope:$scope"

            Write-Host "${functionName}:Checking role assignment for the secret $secretName in the Key Vault $KeyVaultName for the service $ServiceName"
            Get-AzRoleAssignment -Scope $scope -RoleDefinitionName 'Key Vault Secrets User'

            $role = Get-AzRoleAssignment -Scope $scope -RoleDefinitionName 'Key Vault Secrets User' | Where-Object { $_.DisplayName -like '*'+$ServiceName }
            Write-Host "${functionName}:Role:$role"
            if (!$role) {
                Write-Output "Role assignment for the secret $secretName in the Key Vault $KeyVaultName could not be found for the service $ServiceName."
            }
        } 
        else {
          Write-Output "Secret $secretName not found in the Key Vault $KeyVaultName."
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
Write-Debug "${functionName}:ServiceName=$ServiceName"
Write-Debug "${functionName}:ConfigFilePath=$ConfigFilePath"
Write-Debug "${functionName}:KeyVaultName=$KeyVaultName"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Debug "${functionName}:AppConfigModuleDirectory=$AppConfigModuleDirectory"

try {
    Import-Module $PSHelperDirectory -Force
    Import-Module $AppConfigModuleDirectory -Force

    if (Test-Path $ConfigFilePath -PathType Leaf) {
        Write-Debug "${functionName}:ConfigFilePath exists"
        [AppConfigEntry[]]$configItems = Get-AppConfigValuesFromYamlFile -Path $ConfigFilePath -DefaultLabel $ServiceName -KeyVault $KeyVaultName 
        Write-Debug "${functionName}:configItems=$configItems"

        $errors = $configItems | Where-Object { 
            $_.IsKeyVault() 
        } | Test-AppConfigSecretValue -KeyVaultName $KeyVaultName -ServiceName $ServiceName -AdoVariableNames $AdoVariableNames

        if($errors) {
            $errors | ForEach-Object {
                Write-Host "##vso[task.logissue type=error]$($_)"
            }
            throw "Import validation failed for the secrets in the app config file."
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