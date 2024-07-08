<#
.SYNOPSIS
Creates Team RoleAssignment
.DESCRIPTION
Assign project team AD group "contributor" permission to access the teams dedicated resource groups
Assign project team AD group "scoped permissions" to service bus queues and topics
.PARAMETER PipelineCommonDirectory
Mandatory. Directory Path of ADO Pipeline common repo
.PARAMETER TeamName
Mandatory. Team Name
#> 

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$PipelineCommonDirectory,
	[Parameter(Mandatory)]
	[string]$TeamName
)

#------------------------------START : LOCAL TESTING VARIABLES----------------------------------#
# $PipelineCommonDirectory = '.'
# $TeamName = 'fcp-demo'
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

try {

	[System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $PipelineCommonDirectory -ChildPath "templates/powershell/modules/ps-helpers"
	Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
	Import-Module $moduleDir.FullName -Force

	[string]$TeamContributorAcccessGroupName = "AAG-Azure-ADP-$TeamName-Resources-Contributor".ToUpper()
	[string]$command = "az ad group show --group $TeamContributorAcccessGroupName --query id"
	[string]$TeamContributorAcccessGroupId = Invoke-CommandLine -Command $command -IgnoreErrorCode

	if ([string]::IsNullOrEmpty($TeamContributorAcccessGroupId)) {
		Write-Host "##vso[task.logissue type=warning]Team Access group '$TeamContributorAcccessGroupName' does not exist."
		Write-Warning "Team Access group '$TeamContributorAcccessGroupName' does not exist."													
	}
	Write-Host "##vso[task.setvariable variable=TeamContributorAcccessGroupId;]$TeamContributorAcccessGroupId"
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