<#
.SYNOPSIS
Validate json Azure app config file
.DESCRIPTION
Validate json Azure app config file

.PARAMETER Variables
Mandatory. SemiColon seperated variables
.PARAMETER KeyVault
Mandatory. Application Keyvault
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE
.\ImportSecretsToKV.ps1  -Variables <Variables> -KeyVault <KeyVault> PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Variables,
    [Parameter(Mandatory)]
    [string] $KeyVault
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
Write-Debug "${functionName}:Variables=$Variables"
Write-Debug "${functionName}:KeyVault=$KeyVault"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force

    $exitCode = 0

    $VariablesArray = $Variables -split ";"
    foreach ($variable in $VariablesArray) {
        if ([string]::IsNullOrEmpty($variable)) {
            Write-Host "${functionName}:$variable"
            $secret = [Convert]::ToBase64String( [Text.Encoding]::ASCII.GetBytes( "$($variable)") )
            write-output $secret
            $SecureSecret = ConvertTo-SecureString -String $secret -AsPlainText -Force
            Invoke-CommandLine -Command "az keyvault secret set --name $variable --vault-name $KeyVault --value $SecureSecret"
        }
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