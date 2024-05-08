<#
.SYNOPSIS
Get keyvault secret.

.DESCRIPTION
Get keyvault secret and store it in task variable.

.PARAMETER KeyVaultName
Mandatory. KeyVault Name.

.PARAMETER -SecretName
Mandatory. Secret Name.


.EXAMPLE
.\Get-KeyVaultSecret KeyVaultName <KeyVaultName> -SecretName <SecretName> 
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)] 
    [string]$KeyVaultName
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
Write-Debug "${functionName}:KeyVaultName=$KeyVaultName"

try {
    $a = "ADOCALLBACK-API-CLIENT-APP-REG-CLIENT-ID"
    $b = "ADOCALLBACK-API-CLIENT-APP-REG-CLIENT-SECRET"
    $c = "API-AUTH-BACKEND-APP-REG-CLIENT-ID"
    $d = "ADP-PORTAL-AUTH-APP-REG-TENANT-ID"

    Write-Host "Fetching Keyvault secret from KeyVaultName $($KeyVaultName)"
    [string]$ClientID = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $a -AsPlainText -ErrorAction Stop
    [string]$ClientSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $b -AsPlainText -ErrorAction Stop
    [string]$BackendClientID = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $c -AsPlainText -ErrorAction Stop
    [string]$TenantId = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $d -AsPlainText -ErrorAction Stop

    $reqTokenBody = @{
        Grant_Type    = "client_credentials"
        Scope         = "api://$BackendClientID/.default"
        client_Id     = $ClientID
        Client_Secret = $ClientSecret
    }
    $accessToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$($TenantId)/oauth2/v2.0/token" -Method POST -Body $reqTokenBody -ErrorAction Stop
    $authHeaderValue = "Bearer $($accessToken.access_token)"

    Write-Host "##vso[task.setvariable variable=adoCallBackApiAuthHeader;isoutput=true]$($authHeaderValue)"

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