
function Create-Resources {
	param(
		[Parameter(Mandatory)]
		[string]$Environment,
		[Parameter(Mandatory)]
		[string]$RepoName,
		[Parameter(Mandatory)]
		[string]$Pr
	)
	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:Environment=$Environment"
		Write-Debug "${functionName}:RepoName=$RepoName"
		Write-Debug "${functionName}:Pr=$Pr"
	}
	process {
		#Step 1 : Delete PR Resources
              
		#Step 2 : Create ServiceBus Entities Queues and Topics
		Create-ServiceBusEntities -Environment $Environment -RepoName $RepoName -Pr $Pr
		#Step 3 : Create PR databases

	}
	end {
		Write-Debug "${functionName}:Exited"
	}
}

function Delete-Resources {
	param(
		[Parameter(Mandatory)]
		[string]$Environment,
		[Parameter(Mandatory)]
		[string]$RepoName,
		[Parameter(Mandatory)]
		[string]$Pr
	)
	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:Environment=$Environment"
		Write-Debug "${functionName}:RepoName=$RepoName"
		Write-Debug "${functionName}:Pr=$Pr"
	}
	process {

	}
	end {
		Write-Debug "${functionName}:Exited"
	}
}

function Create-ServiceBusEntities {
	param(
		[Parameter(Mandatory)]
		[string]$Environment,
		[Parameter(Mandatory)]
		[string]$RepoName,
		[Parameter(Mandatory)]
		[string]$Pr
	)
	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:Environment=$Environment"
		Write-Debug "${functionName}:RepoName=$RepoName"
		Write-Debug "${functionName}:Pr=$Pr"
	}
	process {
		if (Check-HasResourcesToProvision) {
			Create-AllServiceBusEntities -Environment $Environment -RepoName $RepoName -Pr $Pr
		}
		else {
			Write-Host "There are No resources to provision."
		}

	}
	end {
		Write-Debug "${functionName}:Exited"
	}
}

function Check-HasResourcesToProvision {
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
				$hasResourcesToProvision = $valuesObject.Contains('namespaceQueues') -or $valuesObject.Contains('namespaceTopics')
			}
		}

		return $hasResourcesToProvision
	}
	end {
		Write-Debug "${functionName}:Exited"
	}
}

function Create-AllServiceBusEntities {
	param(
		[Parameter(Mandatory)]
		[string]$Environment,
		[Parameter(Mandatory)]
		[string]$RepoName,
		[Parameter(Mandatory)]
		[string]$Pr
	)
	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:Environment=$Environment"
		Write-Debug "${functionName}:RepoName=$RepoName"
		Write-Debug "${functionName}:Pr=$Pr"
	}
	process {
		[Object[]]$queues = Read-ValuesFile -Resource 'queues'
		Create-Queues -Queues $queues -RepoName $RepoName -Pr $Pr

		[Object[]]$topics = Read-ValuesFile -Resource 'topics'

	}
	end {
		Write-Debug "${functionName}:Exited"
	}
}

function Read-ValuesFile {
	param(
		[Parameter(Mandatory)]
		[string]$Resource
	)
	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Entered"
		Write-Debug "${functionName}:Resource=$Resource"
	}
	process {
		if (Test-Path $Global:InfraChartHomeDir) {

			if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
				Write-Host "powershell-yaml Module does not exists. Installing now.."
				Install-Module powershell-yaml -Force
				Write-Host "powershell-yaml Installed Successfully."
			}
			$valuesYamlPath = "$Global:InfraChartHomeDir\values.yaml"
			[string]$content = Get-Content -Raw -Path $valuesYamlPath
			$valuesObject = ConvertFrom-YAML $content -Ordered
			if ($Resource -eq 'queues') {
				return $valuesObject['namespaceQueues'].name
			}
			elseif ($Resource -eq 'topics') {
				return $valuesObject['namespaceTopics'].name
			}
		}
	}
	end {
		Write-Debug "${functionName}:Exited"
	}
}

function Create-Queues {
	param (
		[Parameter(Mandatory)]
		[Object[]]$Queues,
		[Parameter(Mandatory)]
		[string]$RepoName,
		[Parameter(Mandatory)]
		[string]$Pr
	)
	Create-BuildQueues -Queues $Queues -RepoName $RepoName -Pr $Pr
	if($Pr){

	}
}

function Create-BuildQueues {
	param (
		[Parameter(Mandatory)]
		[Object[]]$Queues,
		[Parameter(Mandatory)]
		[string]$RepoName,
		[Parameter(Mandatory)]
		[string]$Pr
	)
	
	foreach ($queue in $Queues) {
		Write-Host "Creating queue $queue"
	}
}

function Get-BuildQueuePrefix {
	param (
		[Parameter(Mandatory)]
		[Object[]]$Queues,
		[Parameter(Mandatory)]
		[string]$RepoName,
		[Parameter(Mandatory)]
		[string]$Pr
	)
	
}