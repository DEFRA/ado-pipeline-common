<#
.SYNOPSIS
Validate Azure app config file
.DESCRIPTION
Validate Azure app config file

.PARAMETER CommonConfigFilePath
Mandatory. Common App Config file path. This config file conents will be merged to env specific config file.
.PARAMETER ConfigFilePath
Mandatory. App Config file path. 
.PARAMETER AppConfigModuleDirectory
Mandatory. Directory Path of App-Config module
.EXAMPLE
.\ValidateAndMergeConfigFile.ps1  -CommonConfigFilePath <CommonConfigFilePath> -ConfigFilePath <ConfigFilePath> -AppConfigModuleDirectory <AppConfigModuleDirectory>
#> 

[CmdletBinding()]
param(
    [string] $CommonConfigFilePath="D:\workspace\defra-ffc\ffc-demo-web\appConfig\appConfig.yaml",
    #[Parameter(Mandatory)]    
    [string] $ConfigFilePath="D:\workspace\defra-ffc\ffc-demo-web\appConfig\appConfig.snd3.yaml", 
    #[Parameter(Mandatory)]
    [string] $AppConfigModuleDirectory="D:\workspace\defra\ado-pipeline-common\templates\powershell\modules\app-config"
)

function Test-FileContent {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string]$FileContent
    )

    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:FilePath=$FilePath"
        Write-Debug "${functionName}:FileContent=$FileContent"
    }

    process {
        switch -Wildcard ($FilePath) {
            "*.yaml" {
                $errors = Test-Yaml -Yaml $FileContent
                if ($null -eq $errors) {
                    Write-Host "${functionName} File`t`tPassed validation"
                } else {
                    $errors | ForEach-Object {
                        Write-Host "##vso[task.logissue type=error]$_"
                    }
                    throw "File $FilePath failed validation"
                }
            }
            default { throw [System.IO.InvalidDataException]::new($FilePath) }
        }
    }

    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Merge-CommonConfig {
    param(
        [Parameter(Mandatory = $true)][string]$ConfigFilePath,
        [Parameter(Mandatory = $true)][string]$ConfigFileContent,
        [Parameter(Mandatory = $true)][string]$CommonConfigFileContent
    )

    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:ConfigFilePath=$ConfigFilePath"
        Write-Debug "${functionName}:ConfigFileContent=$ConfigFileContent"
        Write-Debug "${functionName}:CommonConfigFileContent=$CommonConfigFileContent"
    }
    process {
        switch -Wildcard ($ConfigFilePath) {
            "*.yaml" { "`n"  | Out-File -append $ConfigFilePath; $CommonConfigFileContent  | Out-File -append $ConfigFilePath }
            default { throw [System.IO.InvalidDataException]::new($ConfigFilePath) }
        }

        Write-Host "${functionName} File $CommonConfigFilePath merged to $ConfigFilePath "
    }
    
    end {
        Write-Debug "${functionName}:Exited"
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
Write-Debug "${functionName}:CommonConfigFilePath=$CommonConfigFilePath"
Write-Debug "${functionName}:ConfigFilePath=$ConfigFilePath"
Write-Debug "${functionName}:AppConfigModuleDirectory=$AppConfigModuleDirectory"

try {

    Import-Module $AppConfigModuleDirectory -Force

    if (Test-Path $CommonConfigFilePath -PathType Leaf) {
        [bool]$commonConfigFileExists = $true
        [string]$CommonConfigFileContent = Get-Content -Raw -Path $CommonConfigFilePath 
        Test-FileContent -FilePath $CommonConfigFilePath -FileContent $CommonConfigFileContent
    }

    if (Test-Path $ConfigFilePath -PathType Leaf) {
        [string]$ConfigFileContent = Get-Content -Raw -Path $ConfigFilePath     
        Write-Debug $ConfigFileContent
        Test-FileContent -FilePath $ConfigFilePath -FileContent $ConfigFileContent
    }

    if ($commonConfigFileExists) {
        Merge-CommonConfig -ConfigFilePath $ConfigFilePath -ConfigFileContent $ConfigFileContent -CommonConfigFileContent $CommonConfigFileContent
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