<#
.SYNOPSIS
Creates Team RoleAssignment
.DESCRIPTION
Assign project team AD group "contributor" permission to access the teams dedicated resource groups (SND1, SND2, SND3, SND4)
Assign project team AD group "reader" permission to access the teams dedicated resource groups (DEV, TST1)
.PARAMETER SubscriptionId
Mandatory. Subscription Id
.PARAMETER InfraChartHomeDir
Mandatory. Directory Path of Infra Chart HomeDirectory
.PARAMETER PipelineCommonDirectory
Mandatory. Directory Path of ADO Pipeline common repo
.PARAMETER TeamName
Mandatory. Team Name
.PARAMETER ServiceResourceGroup
Mandatory. Service ResourceGroup Name
.PARAMETER TeamAccessGroupId
Mandatory. Team AccessGroup Id
.PARAMETER TeamResourceGroupRole
Mandatory. Team ResourceGroup Role
#> 

[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$SubscriptionId,
	[Parameter(Mandatory)]
	[string]$InfraChartHomeDir,
	[Parameter(Mandatory)]
	[string]$PipelineCommonDirectory,
	[Parameter(Mandatory)]
	[string]$TeamName,
	[Parameter(Mandatory)]
	[string]$ServiceResourceGroup,
	[Parameter(Mandatory)]
	[string]$TeamAccessGroupId,
	[Parameter(Mandatory)]
	[string]$TeamResourceGroupRole
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
Write-Debug "${functionName}:SubscriptionId=$SubscriptionId"
Write-Debug "${functionName}:InfraChartHomeDir=$InfraChartHomeDir"
Write-Debug "${functionName}:PipelineCommonDirectory=$PipelineCommonDirectory"
Write-Debug "${functionName}:TeamName=$TeamName"
Write-Debug "${functionName}:ServiceResourceGroup=$ServiceResourceGroup"
Write-Debug "${functionName}:TeamAccessGroupId=$TeamAccessGroupId"
Write-Debug "${functionName}:TeamResourceGroupRole=$TeamResourceGroupRole"

function Set-ResourceGroupRoleAssignment {
	param(
		[Parameter(Mandatory)]
		[string]$TeamName,
		[Parameter(Mandatory)]
		[string]$ServiceResourceGroup,
		[Parameter(Mandatory)]
		[string]$SubscriptionId,
		[Parameter(Mandatory)]
		[string]$TeamAccessGroupId,
		[Parameter(Mandatory)]
		[string]$Role
	)
	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:TeamName=$TeamName"
		Write-Debug "${functionName}:ServiceResourceGroup=$ServiceResourceGroup"
		Write-Debug "${functionName}:SubscriptionId=$SubscriptionId"
		Write-Debug "${functionName}:TeamAccessGroupId=$TeamAccessGroupId"
	}
	process {
		[string]$TeamResourceGroup = "$ServiceResourceGroup-$TeamName".ToLower();		
		[string]$Scope = "/subscriptions/$SubscriptionId/resourceGroups/$TeamResourceGroup"

		Write-Host "Checking if the following resource group exists: $TeamResourceGroup."
		[string]$command = "az group exists --name $TeamResourceGroup"
		$resourceGroupExists = Invoke-CommandLine -Command $command
		Write-Host "Resource group exists: $resourceGroupExists."

		if (([bool]::Parse($resourceGroupExists))) {
			New-RoleAssignment -Scope $Scope -ObjectId $TeamAccessGroupId -RoleDefinitionName $Role -AssigneePrincipalType "Group"	
		}
		else {
			Write-Host "##vso[task.logissue type=warning]$TeamResourceGroup does not exist. RoleAssignment creation skipped."
			Write-Host "$TeamResourceGroup does not exist. RoleAssignment creation skipped."
		}
	}
	end {
		Write-Debug "${functionName}:Exited"
	}    
}

function New-RoleAssignment {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $True)]$Scope,
		[Parameter(Mandatory = $True)]$ObjectId,
		[Parameter(Mandatory = $True)]$RoleDefinitionName,
		[Parameter(Mandatory = $True)]$AssigneePrincipalType
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand    
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:Scope=$Scope"
		Write-Debug "${functionName}:ObjectId=$ObjectId"
		Write-Debug "${functionName}:RoleDefinitionName=$RoleDefinitionName"
		Write-Debug "${functionName}:AssigneePrincipalType=$AssigneePrincipalType"
	}

	process {    
		[string]$RoleAssignment = Invoke-CommandLine -Command "az role assignment list --assignee $ObjectId --role $RoleDefinitionName --scope $Scope" | ConvertFrom-Json

		if ([string]::IsNullOrEmpty($RoleAssignment)) {
			Write-Host "Creating new Role Assignment : RoleDefinitionName = $RoleDefinitionName, Scope = $Scope, ObjectId = $ObjectId"
			Invoke-CommandLine -Command "az role assignment create --assignee-object-id $ObjectId --assignee-principal-type $AssigneePrincipalType --role $RoleDefinitionName --scope $Scope" | Out-Null
			Write-Host "Role Assignment created."
		}
		else {
			Write-Host "Role Assignment already exist for : RoleDefinitionName = $RoleDefinitionName, Scope = $Scope, ObjectId = $ObjectId"
		}
	}

	end {
		Write-Debug "${functionName}:Exited"
	}    
}


try {

	$Global:InfraChartHomeDir = $InfraChartHomeDir

	[System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $PipelineCommonDirectory -ChildPath "templates/powershell/modules/ps-helpers"
	Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
	Import-Module $moduleDir.FullName -Force

	#Team Resource group permissions
	if ([string]::IsNullOrEmpty($TeamAccessGroupId)) {
		Write-Host "##vso[task.logissue type=warning]Team Access group does not exist. ResourceGroupRoleAssignment skipped."
		Write-Warning "Team Access group does not exist. ResourceGroupRoleAssignment skipped."													
	}
	else {
		Set-ResourceGroupRoleAssignment -TeamName $TeamName -ServiceResourceGroup $ServiceResourceGroup -SubscriptionId $SubscriptionId -TeamAccessGroupId $TeamAccessGroupId -Role $TeamResourceGroupRole
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