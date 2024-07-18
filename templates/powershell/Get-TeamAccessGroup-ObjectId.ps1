<#
.SYNOPSIS
Get the Access group object ID.
.DESCRIPTION
Get the Access group object ID and set the value in Task variable.
.PARAMETER PipelineCommonDirectory
Mandatory. Directory Path of ADO Pipeline common repo.
.PARAMETER TeamName
Mandatory. Team Name.
.PARAMETER AccessGroupName
Mandatory. AccessGroup Name.
.PARAMETER AccessGroupIdVariableName
Mandatory. Access GroupId VariableName.
#> 

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$PipelineCommonDirectory,
	[Parameter(Mandatory)]
	[string]$TeamName,
	[Parameter(Mandatory)]
	[string]$AccessGroupName,	
	[Parameter(Mandatory)]
	[string]$AccessGroupIdVariableName
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
Write-Debug "${functionName}:PipelineCommonDirectory=$PipelineCommonDirectory"
Write-Debug "${functionName}:TeamName=$TeamName"
Write-Debug "${functionName}:AccessGroupName=$AccessGroupName"
Write-Debug "${functionName}:AccessGroupIdVariableName=$AccessGroupIdVariableName"

try {

	[System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $PipelineCommonDirectory -ChildPath "templates/powershell/modules/ps-helpers"
	Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
	Import-Module $moduleDir.FullName -Force

	$AccessGroupName = $AccessGroupName.Replace("{TeamName}", 'GG').ToUpper()
	Write-Host "Access group name resolved to $AccessGroupName"
	[string]$command = "az ad group show --group $AccessGroupName --query id"
	[string]$AccessGroupId = Invoke-CommandLine -Command $command -IgnoreErrorCode

	if ([string]::IsNullOrEmpty($AccessGroupId)) {
		Write-Warning "Access group '$AccessGroupName' does not exist."													
	}
	Write-Host "##vso[task.setvariable variable=$AccessGroupIdVariableName;]$AccessGroupId"
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