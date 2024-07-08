<#
.SYNOPSIS
Creates Team RoleAssignment
.DESCRIPTION
Assign project team AD group "contributor" permission to access the teams dedicated resource groups
Assign project team AD group "scoped permissions" to service bus queues and topics
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
.PARAMETER AzureServiceBusResourceGroup
Mandatory. Azure Service Bus Resource Group
.PARAMETER AzureServiceBusNamespace
Mandatory. Azure Service Bus Namespace
.PARAMETER TeamContributorAcccessGroupId
Mandatory. Team Contributor AcccessGroup Id
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
	[string]$AzureServiceBusResourceGroup,
	[Parameter(Mandatory)]
	[string]$AzureServiceBusNamespace,
	[Parameter(Mandatory)]
	[string]$TeamContributorAcccessGroupId
)

#------------------------------START : LOCAL TESTING VARIABLES----------------------------------#
# $SubscriptionId = '55f3b8c6-6800-41c7-a40d-2adb5e4e1bd1'
# $InfraChartHomeDir = 'G:\project\defra-adp\repo\github\defra\services\ffc-demo-calculation-service\helm\ffc-demo-calculation-service-infra'
# $PipelineCommonDirectory = '.'
# $TeamName = 'fcp-demo'
# $ServiceResourceGroup = 'SNDADPINFRG1401'
# $AzureServiceBusResourceGroup = 'SNDADPINFRG1401'
# $AzureServiceBusNamespace = 'SNDADPINFSB1401'
# $TeamContributorAcccessGroupId = ""
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
Write-Debug "${functionName}:SubscriptionId=$SubscriptionId"
Write-Debug "${functionName}:InfraChartHomeDir=$InfraChartHomeDir"
Write-Debug "${functionName}:PipelineCommonDirectory=$PipelineCommonDirectory"
Write-Debug "${functionName}:TeamName=$TeamName"
Write-Debug "${functionName}:ServiceResourceGroup=$ServiceResourceGroup"
Write-Debug "${functionName}:AzureServiceBusResourceGroup=$AzureServiceBusResourceGroup"
Write-Debug "${functionName}:AzureServiceBusNamespace=$AzureServiceBusNamespace"
Write-Debug "${functionName}:TeamContributorAcccessGroupId=$TeamContributorAcccessGroupId"

function Set-ResourceGroupRoleAssignment {
	param(
		[Parameter(Mandatory)]
		[string]$TeamName,
		[Parameter(Mandatory)]
		[string]$ServiceResourceGroup,
		[Parameter(Mandatory)]
		[string]$SubscriptionId,
		[Parameter(Mandatory)]
		[string]$TeamContributorAcccessGroupId
	)
	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:TeamName=$TeamName"
		Write-Debug "${functionName}:ServiceResourceGroup=$ServiceResourceGroup"
		Write-Debug "${functionName}:SubscriptionId=$SubscriptionId"
		Write-Debug "${functionName}:TeamContributorAcccessGroupId=$TeamContributorAcccessGroupId"
	}
	process {
		[string]$TeamResourceGroup = "$ServiceResourceGroup-$TeamName".ToLower();		
		[string]$Scope = "/subscriptions/$SubscriptionId/resourceGroups/$TeamResourceGroup"

		Write-Host "Checking if the following resource group exists: $TeamResourceGroup."
		[string]$command = "az group exists --name $TeamResourceGroup"
		$resourceGroupExists = Invoke-CommandLine -Command $command
		Write-Host "Resource group exists: $resourceGroupExists."

		if (([bool]::Parse($resourceGroupExists))) {
			New-RoleAssignment -Scope $Scope -ObjectId $TeamContributorAcccessGroupId -RoleDefinitionName "Contributor" -AssigneePrincipalType "Group"	
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

function Test-InfraChartHasServiceBusEntities {
	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:Global:InfraChartHomeDir=$Global:InfraChartHomeDir"
	}
	process {
		[bool]$hasResourcesToProvision = $false
		if (Test-Path $Global:InfraChartHomeDir) {

			if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
				Write-Host "powershell-yaml Module does not exists. Installing now.."
				Install-Module powershell-yaml -Force
				Write-Host "powershell-yaml Installed Successfully."
			}

			$valuesYamlPath = "$Global:InfraChartHomeDir\values.yaml"
			[string]$content = Get-Content -Raw -Path $valuesYamlPath
			Write-Debug "$valuesYamlPath content: $content"
			if ($content) {
				$valuesObject = ConvertFrom-YAML $content -Ordered
				$hasResourcesToProvision = ($valuesObject) -and ($valuesObject.Contains('namespaceQueues') -or $valuesObject.Contains('namespaceTopics'))
			}
		}

		return $hasResourcesToProvision
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
	$Global:AzureServiceBusResourceGroup = $AzureServiceBusResourceGroup
	$Global:AzureServiceBusNamespace = $AzureServiceBusNamespace

	[System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $PipelineCommonDirectory -ChildPath "templates/powershell/modules/ps-helpers"
	Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
	Import-Module $moduleDir.FullName -Force

	if ([string]::IsNullOrEmpty($TeamContributorAcccessGroupId)) {
		Write-Host "##vso[task.logissue type=warning]Team Access group '$TeamContributorAcccessGroupName' does not exist."
		Write-Warning "Team Access group '$TeamContributorAcccessGroupName' does not exist."
		$exitCode = 0
		exit $exitCode														
	}
	
	Set-ResourceGroupRoleAssignment -TeamName $TeamName -ServiceResourceGroup $ServiceResourceGroup -SubscriptionId $SubscriptionId -TeamContributorAcccessGroupId $TeamContributorAcccessGroupId
	
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