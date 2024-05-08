<#
.SYNOPSIS
Get keyvault secret.

.DESCRIPTION
Get keyvault secret and store it in task variable.

.PARAMETER KeyVaultName
Mandatory. KeyVault Name.

.PARAMETER -TenantId
Mandatory. Tenant Id.


.EXAMPLE
.\Get-KeyVaultSecret KeyVaultName <KeyVaultName> -TenantId <TenantId> 
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)] 
    [string]$KeyVaultName,
    [Parameter(Mandatory)] 
    [string]$TenantId
)

Set-StrictMode -Version 3.0

[string]$functionName = $MyInvocation.MyCommand
[datetime]$startTime = [datetime]::UtcNow

[int]$exitCode = -1
[bool]$setHostExitCode = (Test-Path -Path ENV:TF_BUILD) -and ($ENV:TF_BUILD -eq "true")
[bool]$enableDebug = $false

Set-Variable -Name ErrorActionPreference -Value Continue -scope global
Set-Variable -Name InformationPreference -Value Continue -Scope global

if ($enableDebug) {
    Set-Variable -Name VerbosePreference -Value Continue -Scope global
    Set-Variable -Name DebugPreference -Value Continue -Scope global
}

Write-Host "${functionName} started at $($startTime.ToString('u'))"
Write-Debug "${functionName}:KeyVaultName=$KeyVaultName"
Write-Debug "${functionName}:TenantId=$TenantId"

try {
    Write-Host "Fetching Keyvault secrets from KeyVaultName $($KeyVaultName)"
    [string]$AdoCallBackApiClientAppClientId = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "ADOCALLBACK-API-CLIENT-APP-REG-CLIENT-ID" -AsPlainText -ErrorAction Stop
    [string]$AdoCallBackApiClientAppClientSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "ADOCALLBACK-API-CLIENT-APP-REG-CLIENT-SECRET" -AsPlainText -ErrorAction Stop
    [string]$ApiAuthBackendAppClientID = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "API-AUTH-BACKEND-APP-REG-CLIENT-ID" -AsPlainText -ErrorAction Stop

    $reqTokenBody = @{
        Grant_Type    = "client_credentials"
        Scope         = "api://$ApiAuthBackendAppClientID/.default"
        client_Id     = $AdoCallBackApiClientAppClientId
        Client_Secret = $AdoCallBackApiClientAppClientSecret
    }
    $accessToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$($TenantId)/oauth2/v2.0/token" -Method POST -Body $reqTokenBody -ErrorAction Stop
    $authHeaderValue = "Bearer $($accessToken.access_token)"

    Write-Host "##vso[task.setvariable variable=adoCallBackApiAuthHeader;isoutput=true;issecret=true]$($authHeaderValue)"

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