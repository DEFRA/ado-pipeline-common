<#
.SYNOPSIS
Validate App-reg manifest yaml file
.DESCRIPTION
Validate App-reg manifest yaml file

.PARAMETER SchemaFilePath
Mandatory. Schema file path.
.PARAMETER ConfigFilePath
Mandatory. App Config file path. 
.PARAMETER AppConfigModuleDirectory
Mandatory. Directory Path of App-Config module
.EXAMPLE
.\ValidateAppRegFile.ps1  -SchemaFilePath <SchemaFilePath> -ConfigFilePath <ConfigFilePath> -AppConfigModuleDirectory <AppConfigModuleDirectory>
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
    [bool]$validFile = $true    
    if (Test-Path $ConfigFilePath -PathType Leaf) {
        [string]$ConfigFilePathContent = Get-Content -Raw -Path $ConfigFilePath 
        if ($ConfigFilePathContent) {
                   
            Import-Module $AppConfigModuleDirectory -Force

            [string]$SchemaFileContent = Get-Content -Raw -Path $SchemaFilePath 
        
            $result = ( Test-Yaml -Yaml $ConfigFilePathContent -Schema $SchemaFileContent)
             
            if ($result -eq $true) {

                $contentObj = $ConfigFilePathContent | ConvertFrom-Yaml
                if ($contentObj) {
                    foreach ($obj in $contentObj) {
                        if ($obj.AppRegName -NotMatch "{{servicename}}-{{environment}}") {
                            Write-Host "AppRegName format is not correct: Should be '{{servicename}}-{{environment}}-suffix'"
                            $validFile = $false
                        }
                        foreach ($redirectUrisObj in $obj.redirectUris) {
                            if ($redirectUrisObj -NotMatch "{{servicename}}.{{environment}}") {
                                Write-Host "redirectUris format is not correct: Should include '{{servicename}}.{{environment}}'"
                                $validFile = $false
                            }
                        }
                        foreach ($accessGroupsObj in $obj.accessGroups) {
                            if ($accessGroupsObj -NotMatch "{{servicename}}-{{environment}}") {
                                Write-Host "accessGroups format is not correct: Should include '{{servicename}}-{{environment}}'"
                                $validFile = $false
                            }
                        }                      
                    }
                }
                if ($validFile) {
                    Write-Host "${functionName} File`t`tPassed validation"
                }
                else {
                    Write-Host "${functionName} File`t`tFailed validation"
                    throw [System.IO.InvalidDataException]::new($ConfigFilePath) 
                }
            }
            else {
                Write-Host "${functionName} File`t`tFailed validation"
                throw [System.IO.InvalidDataException]::new($ConfigFilePath) 
            }        
        }
        else {
            Write-Host "${functionName} File`t`tEmpty"
            throw [System.IO.FileNotFoundException]::new($ConfigFilePath) 
        }
    }
    else {
        Write-Host "${functionName} File`t`tNot found"
        Get-ChildItem
        throw [System.IO.FileNotFoundException]::new($ConfigFilePath) 
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