<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER InfraChartHomeDir
Mandatory. Directory Path of Infra Chart HomeDirectory
.PARAMETER ServiceName
Mandatory. Service Name
.PARAMETER PipelineCommonDirectory
Mandatory. Directory Path of PSHelper module
.EXAMPLE

#> 

[CmdletBinding()]
param(
    # [Parameter(Mandatory)]
    [string]$InfraChartHomeDir,
    # [Parameter(Mandatory)]
    [string]$ServiceName,
    # [Parameter(Mandatory)]
    [string]$PipelineCommonDirectory,
    # [Parameter(Mandatory)]
    [string]$IsPrBuild,
    # [Parameter(Mandatory)]
    [string]$BuildId,
    # [Parameter(Mandatory)]
    [string]$AzureServiceBusResourceGroup,
    # [Parameter(Mandatory)]
    [string]$AzureServiceBusNamespace

)

# $InfraChartHomeDir = 'C:\ganesh\projects\defra\repo\github\Defra\ffc-demo-web\helm\ffc-demo-web-infra'
# $PipelineCommonDirectory = 'C:\ganesh\projects\defra\repo\github\Defra\ado-pipeline-common'
# $ServiceName = 'ffc-demo-web'
# $IsPrBuild = 'true'
# $BuildId = 438708
# $ENV:BUILD_BUILDID = 438708
# $ENV:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER = 305

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
Write-Debug "${functionName}:InfraChartHomeDir=$InfraChartHomeDir"
Write-Debug "${functionName}:ServiceName=$ServiceName"
Write-Debug "${functionName}:PipelineCommonDirectory=$PipelineCommonDirectory"
Write-Debug "${functionName}:IsPrBuild=$IsPrBuild"
Write-Debug "${functionName}:BuildId=$BuildId"
Write-Debug "${functionName}:AzureServiceBusResourceGroup=$AzureServiceBusResourceGroup"
Write-Debug "${functionName}:AzureServiceBusNamespace=$AzureServiceBusNamespace"

try {

    $Global:InfraChartHomeDir = $InfraChartHomeDir
    $Global:AzureServiceBusResourceGroup = $AzureServiceBusResourceGroup
    $Global:AzureServiceBusNamespace = $AzureServiceBusNamespace

    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $PipelineCommonDirectory -ChildPath "templates/powershell/modules/ps-helpers"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
    Import-Module $moduleDir.FullName -Force

    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $PipelineCommonDirectory -ChildPath "templates/powershell/modules/resource-provision"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
    Import-Module $moduleDir.FullName -Force

    Write-Host "Build Id = $ENV:BUILD_BUILDID"    
    Write-Host "Build Number = $ENV:BUILD_BUILDNUMBER"  
    
    $PrNumber = ""
    if($IsPrBuild -eq "true") {
        Write-Host "PR Number = $ENV:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER"
        $PrNumber = $ENV:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER
    }

    Create-Resources -Environment "Snd1" -RepoName $ServiceName -Pr $PrNumber

    Write-Output "##vso[task.setvariable variable=CLAIM3_QUEUE_ADDRESS]ffc-demo-web-pr305-claim3"
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