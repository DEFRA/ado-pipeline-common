<#
.SYNOPSIS
Import Secrets from Variable group to Application Keyvault
.DESCRIPTION
Import Secrets from Variable group to Application Keyvault

.PARAMETER KeyVault
Mandatory. Application Keyvault
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\ImportSecretsToKV.ps1 -KeyVault <KeyVault> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
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
Write-Debug "${functionName}:KeyVault=$KeyVault"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force
    $exitCode = 0                                

    try {

        Write-Host "Get the secret($env:secretName) from KeyVault $KeyVault"
        $oldValue = Invoke-CommandLine -Command "az keyvault secret show --name $env:secretName --vault-name $KeyVault | convertfrom-json"
        Write-Host "Secret($env:secretName) length:$($oldValue.Length)"
    }
    catch {
        $oldValue = $null
    }        

    if(($null -eq $oldValue) -or ($oldValue.value -ne $env:secretValue)){
        Write-Host "Set the secret($env:secretName) to KeyVault $KeyVault"
        Invoke-CommandLine -Command "az keyvault secret set --name $env:secretName --vault-name $KeyVault --value $env:secretValue" > $null
    }

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