<#
.SYNOPSIS
Build Bicep Templates
.DESCRIPTION
Compiles Bicep template and bicepparam files to json templates
.PARAMETER TemplateName
Mandatory. Template file name.
.PARAMETER TemplatePath
Mandatory. Template folder path.
.PARAMETER ParameterFilePath
Optional. Parameter file folder name.
.EXAMPLE
.\Template-Deployment.ps1 -TemplateName <TemplateName> -TemplatePath <TemplatePath> -ParameterFilePath <ParameterFilePath>
#>
[CmdletBinding()]
Param
(
    [Parameter(Mandatory)]
    [string]$TemplateName,
    [Parameter(Mandatory)]
    [string]$TemplatePath,
    [Parameter()]
    [string]$ParameterFilePath = '',
    [Parameter()]
    [string]$WorkingDirectory = $PWD
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
Write-Debug "${functionName}:TemplateName=$TemplateName"
Write-Debug "${functionName}:TemplatePath=$TemplatePath"
Write-Debug "${functionName}:ParameterFilePath=$ParameterFilePath"

try {
    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $WorkingDirectory -ChildPath "templates/powershell/modules/ps-helpers"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
    Import-Module $moduleDir.FullName -Force

    [string]$command = "az bicep build --file $TemplatePath/$TemplateName.bicep"
    Invoke-CommandLine -Command $command
    if ($ParameterFilePath -and $(Test-Path $ParameterFilePath)) {
        $parameterFile = Join-Path -Path $ParameterFilePath -ChildPath "$TemplateName.transformed.bicepparam"
        
        Write-Debug "Building Bicep params $parameterFile"
        $command = "az bicep build-params --file $parameterFile --outfile $ParameterFilePath/$TemplateName.transformed.parameters.json"
        Invoke-CommandLine -Command $command
    }
    else {
        $parameterFile = Join-Path -Path $TemplatePath -ChildPath "$TemplateName.transformed.bicepparam"
        Write-Debug $parameterFile
    
        if (Test-Path $parameterFile -PathType Leaf) {
            Write-Debug "Building Bicep params $parameterFile"
            $command = "az bicep build-params --file $parameterFile --outfile $TemplatePath/$TemplateName.transformed.parameters.json"
            Invoke-CommandLine -Command $command
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