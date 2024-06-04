<#
.SYNOPSIS
Delete Dynamically provisioned cloud resources.
.DESCRIPTION
Delete Dynamically provisioned cloud resource i.e. service bus queues, topics etc.

.PARAMETER PipelineCommonDirectory
Mandatory. Directory Path of ADO Pipeline common repo
.PARAMETER TeamName
Mandatory. Service Name
.PARAMETER IsPrBuild
Mandatory. Is PR Build flag
.PARAMETER Environment
Mandatory. Environment for testing(Not uses yet)
.PARAMETER AzureServiceBusResourceGroup
Mandatory. Azure Service Bus Resource Group
.PARAMETER AzureServiceBusNamespace
Mandatory. Azure Service Bus Namespace

#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PipelineCommonDirectory,
    [Parameter(Mandatory)]
    [string]$TeamName,
    [Parameter(Mandatory)]
    [string]$IsPrBuild,
    [Parameter(Mandatory)]
    [string]$Environment,
    [Parameter(Mandatory)]
    [string]$AzureServiceBusResourceGroup,
    [Parameter(Mandatory)]
    [string]$AzureServiceBusNamespace

)

#------------------------------START : LOCAL TESTING VARIABLES----------------------------------#
# $Environment = 'snd1'
# $PipelineCommonDirectory = '.\ado-pipeline-common'
# $TeamName = 'ffc-demo'
# $ENV:BUILD_BUILDID = 439548
# $IsPrBuild = 'false'
# $ENV:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER = 305
# $AzureServiceBusResourceGroup = 'SNDADPINFRG1401'
# $AzureServiceBusNamespace = 'SNDADPINFSB1401'
#------------------------------END : LOCAL TESTING VARIABLES----------------------------------#

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
Write-Debug "${functionName}:PipelineCommonDirectory=$PipelineCommonDirectory"
Write-Debug "${functionName}:TeamName=$TeamName"
Write-Debug "${functionName}:IsPrBuild=$IsPrBuild"
Write-Debug "${functionName}:Environment=$Environment"
Write-Debug "${functionName}:AzureServiceBusResourceGroup=$AzureServiceBusResourceGroup"
Write-Debug "${functionName}:AzureServiceBusNamespace=$AzureServiceBusNamespace"

try {

    $Global:AzureServiceBusResourceGroup = $AzureServiceBusResourceGroup
    $Global:AzureServiceBusNamespace = $AzureServiceBusNamespace

    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $PipelineCommonDirectory -ChildPath "templates/powershell/modules/ps-helpers"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
    Import-Module $moduleDir.FullName -Force

    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $PipelineCommonDirectory -ChildPath "templates/powershell/modules/resource-provision"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
    Import-Module $moduleDir.FullName -Force
    
    $PrNumber = ""
    if($IsPrBuild -eq "true") {
        Write-Host "PR Number = $ENV:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER"
        $PrNumber = $ENV:SYSTEM_PULLREQUEST_PULLREQUESTNUMBER
    }

    Remove-Resources -Environment $Environment -RepoName $TeamName -Pr $PrNumber

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