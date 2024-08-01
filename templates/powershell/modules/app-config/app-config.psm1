<# 
  .SYNOPSIS 
    Converts the InputObject into an [AppConfigEntry].

  .DESCRIPTION
    Converts the InputObject into an [AppConfigEntry].  It assumes the InputObject has the same
    name properties available on it (case insensitive).  The function will fail if the following properties
    are not present:
    - key
    - label
    - value
    - contenttype

  .INPUTS
    Any type that exposes four properties called
    - key
    - label
    - value
    - contenttype

  .PARAMETER InputObject
    The item to get the values from.

  .OUTPUTS
    [AppConfigEntry] populated from the InputObject
 #>
function ConvertTo-AppConfigEntry {
	param(
		[Parameter(ValueFromPipeline)]
		$InputObject
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
	}

	process {

		if ($null -ne $InputObject) {
			Write-Debug "${functionName}:InputObject.contentType=$($InputObject.contentType)"
			Write-Debug "${functionName}:InputObject.key=$($InputObject.key)"
			Write-Debug "${functionName}:InputObject.label=$($InputObject.label)"
			Write-Debug "${functionName}:InputObject.value=$($InputObject.value)"

			[AppConfigEntry]$entry = [AppConfigEntry]::new()
			$entry.Key = $InputObject.key
			$entry.Value = $InputObject.value
			$entry.Label = $InputObject.label
			if ([string]::IsNullOrWhiteSpace($InputObject.contentType)) {
				$entry.ContentType = '""'
			}
			else {
				$entry.ContentType = $InputObject.contentType
			}

			Write-Output $entry
		}
	}

	end {
		Write-Debug "${functionName}:End"
	}      
}

<#
.SYNOPSIS 
		Gets the key labels from the specified appConfiguration store.
.DESCRIPTION
		Gets the key labels from the specified appConfiguration store.
.PARAMETER ConfigStoreName
		Name of the appConfiguration store.
.PARAMETER Key
		Key to get the labels for.
.PARAMETER LabelStartsWith
		Filter to only return labels that start with this value.
.PARAMETER LabelDoesNotContain
		Filter to only return labels that do not contain this value.
#>
function Get-AppConfigKeyLabels {
	param (
		[Parameter(Mandatory)]
		[string]$ConfigStoreName, 
		[Parameter(Mandatory)]
		[string]$Key,
		[Parameter(Mandatory)]
		[string]$LabelStartsWith,
		[Parameter(Mandatory)]
		[string]$LabelDoesNotContain
	)

	[string]$functionName = $MyInvocation.MyCommand
	Write-Debug "${functionName}:Start"
	Write-Debug "${functionName}:ConfigStoreName=$ConfigStoreName"
	Write-Debug "${functionName}:Key=$Key"
	Write-Debug "${functionName}:LabelStartsWith=$LabelStartsWith"
	Write-Debug "${functionName}:LabelDoesNotContain=$LabelDoesNotContain"

	[System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az appconfig kv list --all --auth-mode login  ")
	[void]$commandBuilder.Append(" --name `"$ConfigStoreName`" ")
	[void]$commandBuilder.Append(" --key `"$Key`" ")
	[void]$commandBuilder.Append(" --key `"$Key`" ")
	[void]$commandBuilder.Append(" --fields key label ")
	[void]$commandBuilder.Append(" --query `"[?starts_with(label, '$LabelStartsWith') && !contains(label,'$LabelDoesNotContain')]`" ")
	
	[string]$command = $commandBuilder.ToString()
	Write-Debug "${functionName}:Command: $command"

	[string]$output = Invoke-Expression -Command $command 
	[int]$processExitCode = $LASTEXITCODE

	if ($processExitCode -ne 0) {
		throw "'$command' exited with non-zero exit code '$processExitCode'"
	}

	Write-Debug "${functionName}:Output: $output"

	Write-Output $output | ConvertFrom-Json

	Write-Debug "${functionName}:End"
}


<# 
  .SYNOPSIS 
    Converts the InputObject into an [AppConfigEntry] and places it into a [hashtable].

  .DESCRIPTION
    Converts the InputObject into an [AppConfigEntry] and places it into a [hashtable] which is keyed 
    on the key and label.  

  .PARAMETER InputObject
    The item to get the values from.

  .NOTES
    The key is {key}:{label} so if label is null/empty, the key will be {key}:

  .INPUTS
    Any type that exposes four properties called
    - key
    - label
    - value
    - contenttype

  .OUTPUTS
    [hashtable] of [AppConfigEntry] items populated from the supplied InputObjects
 #>
function ConvertTo-AppConfigHashTable {
	param(
		[Parameter(ValueFromPipeline)]
		$InputObject
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		[hashtable]$dictionary = @{}
	}

	process {

		[AppConfigEntry]$entry = ConvertTo-AppConfigEntry -InputObject $InputObject

		[string]$uniqueKey = "{0}:{1}" -f $entry.Key, $entry.Label
		
		Write-Debug "${functionName}:Adding $uniqueKey to Hashtable"
		$dictionary.Add($uniqueKey, $entry)
	}

	end {
		Write-Output $dictionary
		Write-Debug "${functionName}:End"
	}    
}

<# 
  .SYNOPSIS 
    Exports the contents of an appConfiguration store to a file.

  .DESCRIPTION
    Exports the contents of an appConfiguration store to a file.  If the file exists it 
    will fail unless the -Force switch is supplied.

  .PARAMETER ConfigStore
    The name of the appConfiguration store to export the values from. 

  .PARAMETER Path
    Path to the file to export the contents to.  If the file exists it will fail unless
    the -Force switch is supplied.

  .PARAMETER Force
    Used to force the overwriting of an existing file specified by Path.
  
  .OUTPUTS
    [System.IO.FileInfo] for the generated file.
#>
function Export-AppConfigValues {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		[string]$ConfigStore,
		[Parameter(Mandatory)]
		[string]$Path,
		[switch]$Force
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		Write-Debug "${functionName}:Path=$Path"
		Write-Debug "${functionName}:Force=$Force"

		[System.IO.FileInfo]$file = $Path
		Write-Debug "${functionName}:File.FullName=$($file.FullName)"

		if ($file.Exists -and -not $Force) {
			throw "File $($File.Name) already exists.  Use -Force to overwrite."
		}

		if (-not $file.Directory.Exists) {
			Write-Debug "${functionName}:Creating output directory $($file.Directory.FullName)"
			$file.Directory.Create()
		}
	}

	process {
		[string]$json = Get-AppConfigValues -ConfigStore $ConfigStore -AsJson
		Write-Debug "${functionName}:AppConfigvaluesJson=$json"

		Write-Debug "${functionName}:Writing AppConfigvaluesJson to $($file.FullName):"
		Set-Content -Path $file.FullName -Value $json -Force
		$file.Refresh()
		Write-Output $file
	}

	end {
		Write-Debug "${functionName}:End"
	}
}

<# 
  .SYNOPSIS 
    Gets the contents of an appConfiguration store.

  .DESCRIPTION
    Gets the contents of an appConfiguration store.  

  .PARAMETER ConfigStore
    The name of the appConfiguration store to get the values from. 

  .PARAMETER Label
    Can filter by label.  Null/empty means all labels.  

  .PARAMETER AsJson
    This switch changes the output from [AppConfigEntry] to a json [string]

  .NOTES
    It's currently not possible to get unlabelled items.  The Label filter is only to limit to a label.
  
  .OUTPUTS
    [AppConfigEntry] for each item in the ConfigStore
    or
    [string] if the -AsJson switch is supplied
#>
function Get-AppConfigValues {
	param (
		[Parameter(Mandatory)]
		[string]$ConfigStore,
		[string]$Label,
		[switch]$AsJson
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		Write-Debug "${functionName}:ConfigStore=$ConfigStore"
		Write-Debug "${functionName}:Label=$Label"
	}
    
	process {
		
		[System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az appconfig kv list --all --auth-mode login  ")
		[void]$commandBuilder.Append(" --name `"$ConfigStore`" ")
		[void]$commandBuilder.Append(" --query `"[*].{ key:key, label:label, value:value, contentType:contentType } `"")

		if ([string]::IsNullOrWhiteSpace($Label)) {
			[void]$commandBuilder.Append(" --label `"*`" ")
		}
		else {
			[void]$commandBuilder.Append(" --label `"$Label`" ")
		}

		[string]$command = $commandBuilder.ToString()

		Write-Debug "${functionName}:Command=$command"
       
		[string]$output = Invoke-Expression -Command $command 
		[int]$processExitCode = $LASTEXITCODE

		if ($processExitCode -ne 0) {
			throw "'$command' exited with non-zero exit code '$processExitCode'"
		}
		elseif ([string]::IsNullOrEmpty($output)) {
			throw "'$command' returned no output"
		}

		$result = $output | ConvertFrom-Json | ConvertTo-AppConfigEntry | Sort-Object -Property Key, Label

		if ($AsJson) {
			[string]$json = $result | ConvertTo-Json  
			Write-Output $json
		}
		else {
			Write-Output $result
		}
	}

	end {
		Write-Debug "${functionName}:End"
	}
}

<# 
  .SYNOPSIS 
    Gets the [AppConfigEntry] items from the specified file.

  .DESCRIPTION
    Gets the [AppConfigEntry] items from the specified file.

  .PARAMETER Path
    The path to the file to read the contents from.

  .NOTES
    The file format is json.  
        {
            "Key": "",
            "Value": "",
            "Label": "",
            "ContentType": ""
        }

  .INPUTS
    [string] names of files to get the [AppConfigEntry] items from 

  .OUTPUTS
    [AppConfigEntry] for each entry in the file
#>
function Get-AppConfigValuesFromFile {
	param (
		[Parameter(ValueFromPipeline, Mandatory)]
		[string]$Path
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
	}

	process {
		Write-Debug "${functionName}:FilePath=$Path"

		[System.IO.FileInfo]$file = $Path
		Write-Debug "${functionName}:File.FullName=$($file.FullName)"

		if (-not $file.Exists) {
			throw [System.IO.FileNotFoundException]::new($file.FullName)
		}

		[string]$content = Get-Content -Path $Path

		Write-Debug "${functionName}:FileContent=$content"

		$output = $content | ConvertFrom-Json | ConvertTo-AppConfigEntry | Sort-Object -Property Key, Label

		Write-Output $output
	}

	end {
		Write-Debug "${functionName}:End"
	}
}


<# 
  .SYNOPSIS 
    Gets the [AppConfigEntry] items from the specified yaml file.

  .DESCRIPTION
    Gets the [AppConfigEntry] items from the specified yaml file.

  .PARAMETER Path
    The path to the file to read the contents from.

  .NOTES
    The file format is json.  
    	- key: ""
          value: ""
    	  type: "" or "keyvault"

  .INPUTS
    [string] names of files to get the [AppConfigEntry] items from 
	[string] default Label to be applied
	[string] keyvault name for any objects of type keyvault

  .OUTPUTS
    [AppConfigEntry] for each entry in the file
#>
function Get-AppConfigValuesFromYamlFile {
	param (
		[Parameter(ValueFromPipeline, Mandatory)]
		[string]$Path,
		[Parameter(ValueFromPipeline, Mandatory)]
		[string]$DefaultLabel,
		[Parameter(ValueFromPipeline, Mandatory)]
		[string]$KeyVault
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		Install-Module powershell-yaml -Force -Debug:$false -Verbose:$false
		Import-Module powershell-yaml -Force -Debug:$false -Verbose:$false
	}

	process {
		Write-Debug "${functionName}:FilePath=$Path"

		[System.IO.FileInfo]$file = $Path
		Write-Debug "${functionName}:File.FullName=$($file.FullName)"

		if (-not $file.Exists) {
			throw [System.IO.FileNotFoundException]::new($file.FullName)
		}

		[string]$content = Get-Content -Raw -Path $Path

		Write-Debug "${functionName}:FileContent=$content"

		[string]$kvContentType = 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'

		$ConfigFileContent = $content | ConvertFrom-YAML
		foreach ($configFileObj in $ConfigFileContent) {
			$configFileObj.Label = $DefaultLabel
			if ($configFileObj.ContainsKey("type") -and ($configFileObj.type -eq "keyvault" -or $configFileObj.type -eq "keyvaultsecret") ) {
				$configFileObj.ContentType = $kvContentType

				[System.Text.StringBuilder]$kvBuilder = [System.Text.StringBuilder]::new("{ `"uri`" : `"https://")
				[void]$kvBuilder.Append($KeyVault)
				[void]$kvBuilder.Append(".vault.azure.net/Secrets/")
				[void]$kvBuilder.Append($configFileObj.Value)
				[void]$kvBuilder.Append("`" } ")
				[string]$keyVaultRef = $kvBuilder.ToString()

				$configFileObj.Value = $keyVaultRef
			}
		}

		$output = $ConfigFileContent | ConvertTo-AppConfigEntry | Sort-Object -Property Key, Label

		Write-Output $output
	}

	end {
		Write-Debug "${functionName}:End"
	}
}

<# 
  .SYNOPSIS 
    Imports appConfiguration values into the specified store from the specified file.

  .DESCRIPTION
    Imports appConfiguration values into the specified store from the specified file.
    It will only change items that are different.  It will not touch any item that hasn't changed.

  .PARAMETER Path
    The path to the file to import.

  .PARAMETER ConfigStore
    The name of the appConfiguration store to import to.

  .PARAMETER Label
    The name of the service

  .PARAMETER DeleteEntriesNotInFile
    This switch enables the removal of any entry that isn't contained in the import file.  

  .PARAMETER KeyVaultName
    The name of the keyvault to be used for objects while importing from yaml file

  .PARAMETER BuildId
  Build Id to update the sentinel value

  .PARAMETER Version
    Version to create the sentinel label

  .NOTES
    The file format is json.  
        {
            "Key": "",
            "Value": "",
            "Label": "",
            "ContentType": ""
        }

  .OUTPUTS
    [AppConfigEntry] for each entry that was created/updated.
    If all the items in the config store are the same as the import file then it will not return anything.
#>
function Import-AppConfigValues {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		[string]$Path,
		[Parameter(Mandatory)]
		[string]$ConfigStore,
		[Parameter(Mandatory)]
		[string]$Label,
		[switch]$DeleteEntriesNotInFile,
		[string]$KeyVaultName,
		[string]$BuildId,
		[string]$Version,
		[bool]$FullBuild = $false
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		Write-Debug "${functionName}:ConfigStore=$ConfigStore"
		Write-Debug "${functionName}:Label=$Label"
		Write-Debug "${functionName}:Path=$Path"
		Write-Debug "${functionName}:KeyVaultName=$KeyVaultName"
		Write-Debug "${functionName}:BuildId=$BuildId"
		Write-Debug "${functionName}:Version=$Version"
		Write-Debug "${functionName}:FullBuild=$FullBuild"

		[array]$outputs = @()
		[System.IO.FileInfo]$importFile = $Path

		if (-not $importFile.Exists) {
			throw [System.IO.FileNotFoundException]::new($importFile.FullName)
		}
	}

	process {
		[AppConfigEntry[]]$existingItems = Get-AppConfigValues -ConfigStore $ConfigStore -Label $Label

		switch ($importFile.Extension) {
			".json" {
				[AppConfigEntry[]]$desiredItems = Get-AppConfigValuesFromFile -Path $importFile.FullName
			}
			".yaml" {
				[AppConfigEntry[]]$desiredItems = Get-AppConfigValuesFromYamlFile -Path $importFile.FullName -DefaultLabel $Label -KeyVault $KeyVaultName 
			}
			default {
				throw [System.IO.InvalidDataException]::new($importFile.FullName)
			}
		}

		#Validate if each record has a label matching the service
		$desiredItems | ForEach-Object {
			if ($_.Label -ne $Label) {
				throw [System.IO.InvalidDataException]::new("Invalid Label for $item.key ")
			}
		}
		
		[AppConfigDifferences]$delta = New-AppConfigDifference -Source $desiredItems -Destination $existingItems
        
		if ($delta.Add.Count -gt 0) {
			$outputs += @($delta.Add | Set-AppConfigValue -ConfigStore $ConfigStore)
		}

		if ($delta.Update.Count -gt 0) {
			$outputs += @($delta.Update | Set-AppConfigValue -ConfigStore $ConfigStore)
		}

		if ($DeleteEntriesNotInFile -and $delta.Remove.Count -gt 0) {
			$outputs += @($delta.Remove | Remove-AppConfigValue -ConfigStore $ConfigStore)
		}

		[string]$sentinelKey = 'Sentinel'
		[string]$sentinelUniqueKey = "{0}:{1}" -f $sentinelKey, $Label
		[hashtable]$existingAppConfig = $existingItems | ConvertTo-AppConfigHashTable

		if ($FullBuild) {
			[AppConfigEntry]$sentinelItem = [AppConfigEntry]::new()
			$sentinelItem.Key = $sentinelKey
			$sentinelItem.value = $BuildId
			if (-not $existingAppConfig.ContainsKey($sentinelUniqueKey)) {
				Write-Debug "${functionName}:process:Creating sentinel key"
				$sentinelItem.Label = $Label
				$outputs += @($sentinelItem  | Set-AppConfigValue -ConfigStore $ConfigStore)
			}
			$sentinelItem.Label = "$Label-$Version"
			$outputs += @($sentinelItem  | Set-AppConfigValue -ConfigStore $ConfigStore)
			
		}
		elseif ($outputs) {
			#If there are any changes in config values, update sentinel key.
			if ($existingAppConfig.ContainsKey($sentinelUniqueKey)) {
				Write-Debug "${functionName}:process:Updating sentinel key"
				[AppConfigEntry]$sentinelItem = $existingAppConfig[$sentinelUniqueKey]
				$sentinelItem.value = $BuildId
				$outputs += @($sentinelItem  | Set-AppConfigValue -ConfigStore $ConfigStore)
			}
		}
	}

	end {
		if ($FullBuild) {
			try {
				Write-Host "Cleaning up old sentinel key labels"
				Get-AppConfigKeyLabels -ConfigStoreName $ConfigStore -Key 'Sentinel' -LabelStartsWith "$Label-" -LabelDoesNotContain "$Label-$Version" | ForEach-Object {
					Remove-AppConfigValue -InputObject $_ -ConfigStore $ConfigStore
				}
			}
			catch {
				Write-Warning "Failed to cleanup old sentinel key labels."
			}
		}

		if ($outputs.Count -gt 0) {
			[AppConfigEntry[]]$results = $outputs | ConvertFrom-Json | ConvertTo-AppConfigEntry
			Write-Output $results
		}

		Write-Debug "${functionName}:End"
	}
}

<# 
  .SYNOPSIS 
    Determines the differences between two sets of [AppConfigEntry]s.

  .DESCRIPTION
    Determines the differences between two sets of [AppConfigEntry]s.

  .PARAMETER Source
    The set of entries representing the source being published.

  .PARAMETER Source
    The set of entries representing the destination being published to.

  .OUTPUTS
    [AppConfigDifferences] containing the differences (if any)
#>
function New-AppConfigDifference {
	param (
		[Parameter(Mandatory)][array]$Source,
		[array]$Destination
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		[hashtable]$sourceAppConfig = $Source | ConvertTo-AppConfigHashTable
		[hashtable]$destinationAppConfig = @{}
		[hashtable]$addEntries = @{}
		[hashtable]$removeEntries = @{}
		[hashtable]$updateEntries = @{}

		if ($null -ne $Destination -and $Destination.Count -gt 0) {
			$destinationAppConfig = $Destination | ConvertTo-AppConfigHashTable
		}
		else {
			Write-Verbose "Destination is empty"
		}
	}

	process {

		[string]$sentinelKey = 'Sentinel:'

		$sourceAppConfig.Keys | ForEach-Object {
			Write-Debug "${functionName}:SourceKey=$_"
			[AppConfigEntry]$sourceItem = $SourceAppConfig[$_]
			if (-not $_.StartsWith($sentinelKey)) {
				if ($destinationAppConfig.ContainsKey($_)) {
					[AppConfigEntry]$destinationItem = $destinationAppConfig[$_]
					[string]$sourceValue = $sourceItem.Value
					[string]$sourceContentType = $sourceItem.ContentType
					[string]$destinationValue = $destinationItem.Value
					[string]$destinationContentType = $destinationItem.ContentType
					[bool]$same = ($sourceValue -ceq $destinationValue)
					if (-not $sourceItem.IsKeyVault()) {
						$same = $same -and `
						(
							([string]::IsNullOrWhiteSpace($sourceContentType) -and [string]::IsNullOrWhiteSpace($destinationContentType)) `
								-or 
							($sourceContentType -ceq $destinationContentType)
						)
					}
					Write-Debug "${functionName}:${same}:sourceValue/destinationValue=${sourceValue}/${destinationValue}"
	
					if (-not $same) {
						Write-Debug "${functionName}:$_ differs - needs updated"
						$updateEntries.Add($_, $sourceItem)
					}
				}
				else {
					Write-Debug "${functionName}:$_ not found in destination"
					$addEntries.Add($_, $sourceItem)
				}
			}
		}

		$destinationAppConfig.Keys | ForEach-Object {
			[bool]$exists = $sourceAppConfig.ContainsKey($_)
			Write-Debug "${functionName}:${exists}:destinationKey=$_"

			if (-not $exists -and -not $_.StartsWith($sentinelKey)) {
				Write-Verbose "$_ surplus - needs removed"
				$removeEntries.Add($_, $destinationAppConfig[$_])
			}
		}
	}

	end {
		[AppConfigDifferences]$differences = [AppConfigDifferences]::new()
		$differences.Add = $addEntries.Values
		$differences.Update = $updateEntries.Values
		$differences.Remove = $removeEntries.Values		

		Write-Output $differences
        
		Write-Debug "${functionName}:End"
	}
}

<# 
  .SYNOPSIS 
    Removes the specified item from the specified appConfiguration store.

  .DESCRIPTION
    Removes the specified item from the specified appConfiguration store.

  .PARAMETER InputObject
    The item to be removed.

  .PARAMETER ConfigStore
    The appConfiguration store to remove the item from.

  .INPUTS
    [AppConfigEntry] to be removed from the appConfiguration store

  .OUTPUTS
    [string] raw output from the az appconfig kv delete command
#>
function Remove-AppConfigValue {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[AppConfigEntry]$InputObject,
		[Parameter(Mandatory)]
		[string]$ConfigStore
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		Write-Debug "${functionName}:ConfigStore=$ConfigStore"
	}
    
	process {
		Write-Debug "${functionName}:InputObject.Key=$($InputObject.Key)"
		Write-Debug "${functionName}:InputObject.Label=$($InputObject.Label)"

		[string]$label = $InputObject.Label
		[string]$key = $InputObject.Key

		[System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az appconfig kv delete --auth-mode login --yes ")
		[void]$commandBuilder.Append(" --name `"$ConfigStore`" ")
		[void]$commandBuilder.Append(" --key `"$key`" ")

		if (-not [string]::IsNullOrWhiteSpace($label)) {
			[void]$commandBuilder.Append(" --label `"$label`" ")
		}

		[string]$command = $commandBuilder.ToString()

		Write-Debug "${functionName}:Command=$command"
		Write-Verbose "Removing ${key}:${label} from $ConfigStore"

		if ($PSCmdlet.ShouldProcess($command, $ConfigStore, $functionName)) {
			[string]$output = Invoke-Expression -Command $command 
			[int]$processExitCode = $LASTEXITCODE
			Write-Output $output
			if ($processExitCode -ne 0) {
				throw "'$command' exited with non-zero exit code '$processExitCode'"
			}
		}
	}

	end {
		Write-Debug "${functionName}:End"
	}
}

<# 
  .SYNOPSIS 
    Commits the specified item into the specified appConfiguration store.

  .DESCRIPTION
    Commits the specified item into the specified appConfiguration store.

  .PARAMETER InputObject
    The item to be added/updated in the appConfiguration store.

  .PARAMETER ConfigStore
    The appConfiguration store to add/update the item.
  
  .NOTES
    The raw output from az appconfig kv set/set-keyvault is a json string
    representing the item that was added/updated.

  .INPUTS
    [AppConfigEntry] to be added/updated in the appConfiguration store

  .OUTPUTS
    [string] raw output from the az appconfig kv set/set-keyvault command
#>
function Set-AppConfigValue {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory, ValueFromPipeline)]
		[AppConfigEntry]$InputObject,
		[Parameter(Mandatory)]
		[string]$ConfigStore
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		Write-Debug "${functionName}:ConfigStore=$ConfigStore"
	}
    
	process {
		Write-Debug "${functionName}:InputObject.Key=$($InputObject.Key)"
		Write-Debug "${functionName}:InputObject.Label=$($InputObject.Label)"
		Write-Debug "${functionName}:InputObject.Value=$($InputObject.Value)"
		Write-Debug "${functionName}:InputObject.ContentType=$($InputObject.ContentType)"

		[string]$key = $InputObject.Key
		[string]$label = $InputObject.Label
		[string]$contentType = $InputObject.ContentType
		[bool]$isKeyVault = $InputObject.IsKeyVault()

		Write-Debug "${functionName}:IsKeyVault=$isKeyVault"

		[System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az appconfig kv ")
		if ($isKeyVault) {
			[void]$commandBuilder.Append(" set-keyvault ")
			[string]$secretIdentifier = $InputObject.GetSecretIdentifier()
			[void]$commandBuilder.Append(" --secret-identifier `"$secretIdentifier`" ")
		} 
		else {
			[void]$commandBuilder.Append(" set ")
			[void]$commandBuilder.Append(" --value `"$($InputObject.Value)`" ")
			if ([string]::IsNullOrWhiteSpace($contentType) -or $contentType -eq '""') {
				[void]$commandBuilder.Append(" --content-type '`"`"' ")
			}
			else {
				[void]$commandBuilder.Append(" --content-type `"$contentType`" ")
			}
		}

		[void]$commandBuilder.Append(" --auth-mode login ")
		[void]$commandBuilder.Append(" --yes ")
		[void]$commandBuilder.Append(" --name `"$ConfigStore`" ")
		[void]$commandBuilder.Append(" --key `"$key`" ")

		if (-not [string]::IsNullOrWhiteSpace($label)) {
			[void]$commandBuilder.Append(" --label `"$label`" ")
		}

		[string]$command = $commandBuilder.ToString()

		Write-Debug "${functionName}:Command=$command"

		if ($isKeyVault) {
			Write-Verbose "Setting keyvault ${key}:${label} in $ConfigStore"
		} 
		else {
			Write-Verbose "Setting ${key}:${label} in $ConfigStore"
		}

		if ($PSCmdlet.ShouldProcess($command, $ConfigStore, $functionName)) {
			[string]$output = Invoke-Expression -Command $command 
			[int]$processExitCode = $LASTEXITCODE
			Write-Output $output
			if ($processExitCode -ne 0) {
				throw "'$command' exited with non-zero exit code '$processExitCode'"
			}
		}
	}

	end {
		Write-Debug "${functionName}:End"
	}
}

function Test-Yaml {
	param(
		[Parameter(Mandatory)]
		[string] $Yaml
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:Start"
		Write-Debug "${functionName}:Yaml=$Yaml"

		if (!(Get-Module -ListAvailable -Name powershell-yaml -Verbose:$false -Debug:$false)) {
			Install-Module -Name powershell-yaml -Force -Verbose:$false -Debug:$false
		}
	}

	process {
		$secretNameRegex = '^{{serviceName}}-[a-zA-Z0-9][a-zA-Z0-9-]{0,74}[a-zA-Z0-9]$'
		$keyvaultSecretRule = { param($item) 
			$keyValid = $item.key -is [string]
			$valueValid = $item.value -is [string] -and $item.value -match $secretNameRegex
			$valid = $keyValid -and $valueValid
			$reason = if (-not $keyValid) { "key is not a string" } elseif (-not $valueValid) { "value is not a valid. The secret name must be unique within a Key Vault. The name must be a 1-127 character string, starting with a letter and containing only 0-9, a-z, A-Z, - and the name must start with '{{serviceName}}-'" } else { $null }
			return $valid, $reason
		}

		$rules = @{
			'string'         = { param($item) 
				$keyValid = $item.key -is [string]
				$valueValid = $item.value -is [string]
				$valid = $keyValid -and $valueValid
				$reason = if (-not $keyValid) { "key is not a string" } elseif (-not $valueValid) { "value is not a string" } else { $null }
				return $valid, $reason
			}
			'keyvault'       = $keyvaultSecretRule
			'keyvaultsecret' = $keyvaultSecretRule
		}
		
		$data = ConvertFrom-Yaml $Yaml
		
		foreach ($item in $data) {
			$type = if ($item.ContainsKey('type')) { $item.type.ToLower() } else { 'string' }
			if ($rules.ContainsKey($type)) {
				$valid, $reason = & $rules[$type] $item
				if (-not $valid) {
					Write-Output "Validation failed for item $($item | ConvertTo-Json -Compress) : $($reason)"
				}
			}
			else {
				Write-Output "Validation failed for item $($item | ConvertTo-Json -Compress): unknown type '$type'"
			}
		}
	}

	end {
		Write-Debug "${functionName}:End"
	}	
}
