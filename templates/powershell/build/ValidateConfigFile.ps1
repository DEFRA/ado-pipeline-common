<#
.SYNOPSIS
Validate Azure app config file
.DESCRIPTION
Validate Azure app config file

.PARAMETER SchemaFilePath
Mandatory. Schema file path. 
.PARAMETER ConfigFilePath
Mandatory. App Config file path. 
.PARAMETER AppConfigModuleDirectory
Mandatory. Directory Path of App-Config module
.EXAMPLE
.\ValidateConfigFile.ps1  -SchemaFilePath <SchemaFilePath> -ConfigFilePath <ConfigFilePath> -AppConfigModuleDirectory <AppConfigModuleDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $SchemaFilePath,
    [Parameter(Mandatory)]
    [string] $ConfigFilePath,
    [Parameter(Mandatory)]
    [string] $AppConfigModuleDirectory
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
Write-Debug "${functionName}:SchemaFilePath=$SchemaFilePath"
Write-Debug "${functionName}:ConfigFilePath=$ConfigFilePath"
Write-Debug "${functionName}:AppConfigModuleDirectory=$AppConfigModuleDirectory"

try {

    Import-Module $AppConfigModuleDirectory -Force

    if (Test-Path $ConfigFilePath -PathType Leaf) {
        [string]$ConfigFileContent = Get-Content -Encoding UTF8 -Raw -Path $ConfigFilePath 
        [string]$SchemaFileContent = Get-Content -Encoding UTF8 -Raw -Path $SchemaFilePath 
        Write-Host $ConfigFileContent
        Write-Host $SchemaFileContent
        if ($ConfigFilePath.EndsWith(".json")) {        
            $result = ( $ConfigFileContent | Test-Json -Schema $SchemaFileContent)
        }
        elseif ($ConfigFilePath.EndsWith(".yaml")) {

            $result = ( $ConfigFileContent | Test-Yaml -Schema $SchemaFileContent)
        }
        else {
            throw [System.IO.InvalidDataException]::new($ConfigFilePath)            
        }
       
        if ($result -eq $true) {
            Write-Host "${functionName} JSON File`t`tPassed validation"
        }
        else {
            Write-Host "${functionName} JSON File`t`tFailed validation"
            throw [System.IO.InvalidDataException]::new($ConfigFilePath) 
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
