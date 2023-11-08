<#
.SYNOPSIS
Validate Azure app config file
.DESCRIPTION
Validate Azure app config file

.PARAMETER SchemaFilePath
Mandatory. Schema file path.
.PARAMETER CommonConfigFilePath
Mandatory. Common App Config file path. This config file conents will be merged to env specific config file.
.PARAMETER ConfigFilePath
Mandatory. App Config file path. 
.PARAMETER AppConfigModuleDirectory
Mandatory. Directory Path of App-Config module
.EXAMPLE
.\ValidateAndMergeConfigFile.ps1  -SchemaFilePath <SchemaFilePath> -CommonConfigFilePath <CommonConfigFilePath> -ConfigFilePath <ConfigFilePath> -AppConfigModuleDirectory <AppConfigModuleDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $SchemaFilePath,
    [string] $CommonConfigFilePath,
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
Write-Debug "${functionName}:CommonConfigFilePath=$CommonConfigFilePath"
Write-Debug "${functionName}:ConfigFilePath=$ConfigFilePath"
Write-Debug "${functionName}:AppConfigModuleDirectory=$AppConfigModuleDirectory"

try {

    [bool]$CommonConfigFileExists = $false

    Import-Module $AppConfigModuleDirectory -Force
    if (Test-Path $SchemaFilePath -PathType Leaf) {
        [string]$SchemaFileContent = Get-Content -Raw -Path $SchemaFilePath 
    }

    if (Test-Path $CommonConfigFilePath -PathType Leaf) {
        [bool]$CommonConfigFileExists = $true
        [string]$CommonConfigFileContent = Get-Content -Raw -Path $CommonConfigFilePath 
        if ($CommonConfigFilePath.EndsWith(".json")) {        
            $result = ( Test-Json -Json $CommonConfigFileContent -Schema $SchemaFileContent)
        }
        elseif ($CommonConfigFilePath.EndsWith(".yaml")) {

            $result = ( Test-Yaml -Yaml $CommonConfigFileContent -Schema $SchemaFileContent)
        }        
        if ($result -eq $true) {
            Write-Host "${functionName} File`t`tPassed validation"
        }
        else {
            Write-Host "${functionName} File`t`tFailed validation"
            throw [System.IO.InvalidDataException]::new($CommonConfigFilePath) 
        }
    }

    if (Test-Path $ConfigFilePath -PathType Leaf) {
        [string]$ConfigFileContent = Get-Content -Raw -Path $ConfigFilePath     
        Write-Debug $ConfigFileContent
        
        if ($ConfigFilePath.EndsWith(".json")) {        
            $result = ( Test-Json -Json $ConfigFileContent -Schema $SchemaFileContent)
        }
        elseif ($ConfigFilePath.EndsWith(".yaml")) {

            $result = ( Test-Yaml -Yaml $ConfigFileContent -Schema $SchemaFileContent)
        }        
       
        if ($result -eq $true) {
            Write-Host "${functionName} File`t`tPassed validation"
        }
        else {
            Write-Host "${functionName} File`t`tFailed validation"
            throw [System.IO.InvalidDataException]::new($ConfigFilePath) 
        }
    }

    if ($CommonConfigFileExists) {
        if ($ConfigFilePath.EndsWith(".json")) { 
            @($ConfigFileContent; $CommonConfigFileContent) | ConvertTo-Json | Out-File $ConfigFilePath
        }
        elseif ($ConfigFilePath.EndsWith(".yaml")) {
            "`n"  | Out-File -append $ConfigFilePath
            $CommonConfigFileContent  | Out-File -append $ConfigFilePath
        }
        else {
            throw [System.IO.InvalidDataException]::new($ConfigFilePath)            
        }
        Write-Host "${functionName} File $CommonConfigFilePath merged to $ConfigFilePath "
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