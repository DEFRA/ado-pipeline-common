class AppConfigDifferences {
	[array]$Add = @()
	[array]$Update = @()
	[array]$Remove = @()
}

class AppConfigEntry {
	[string]$Key
	[string]$Value
	[string]$Label
	[string]$ContentType
	[bool] IsKeyVault() {
		return (-not [string]::IsNullOrEmpty($this.Value) -and $this.Value.StartsWith("{")) 
	}
	[string] GetSecretIdentifier() {
		[string]$result = $null
		if ($this.IsKeyVault()) {
			[hashtable]$item = ConvertFrom-Json -InputObject $this.Value -AsHashtable
			[string]$itemKey = $item.Keys[0]
			$result = $item[$itemKey]
		}
		return $result
	}
}

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
		Write-Debug "${functionName}:begin:Start"
		Write-Debug "${functionName}:begin:End"
	}

	process {
		Write-Debug "${functionName}:process:Start"

		if ($null -ne $InputObject) {
			Write-Debug "${functionName}:process:InputObject.contentType=$($InputObject.contentType)"
			Write-Debug "${functionName}:process:InputObject.key=$($InputObject.key)"
			Write-Debug "${functionName}:process:InputObject.label=$($InputObject.label)"
			Write-Debug "${functionName}:process:InputObject.value=$($InputObject.value)"

			[AppConfigEntry]$entry = [AppConfigEntry]::new()
			$entry.Key = $InputObject.key
			$entry.Value = $InputObject.value
			$entry.Label = $InputObject.label
			if ([string]::IsNullOrWhiteSpace($InputObject.contentType)) {
				$entry.ContentType = $null
			}
			else {
				$entry.ContentType = $InputObject.contentType
			}

			Write-Output $entry
		}

		Write-Debug "${functionName}:process:End"
	}

	end {
		Write-Debug "${functionName}:end:Start"
		Write-Debug "${functionName}:end:End"
	}      
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
		Write-Debug "${functionName}:begin:Start"

		[hashtable]$dictionary = @{}

		Write-Debug "${functionName}:begin:End"
	}

	process {
		Write-Debug "${functionName}:process:Start"
        
		[AppConfigEntry]$entry = ConvertTo-AppConfigEntry -InputObject $InputObject

		[string]$uniqueKey = "{0}:{1}" -f $entry.Key, $entry.Label
		Write-Debug "${functionName}:process:uniqueKey=$uniqueKey"
		$dictionary.Add($uniqueKey, $entry)

		Write-Debug "${functionName}:process:End"
	}


	end {
		Write-Debug "${functionName}:end:Start"
		Write-Output $dictionary
		Write-Debug "${functionName}:end:End"
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
		Write-Debug "${functionName}:begin:Start"
		Write-Debug "${functionName}:process:Path=$Path"
		Write-Debug "${functionName}:process:Path=$Force"

		[System.IO.FileInfo]$file = $Path
		Write-Debug "${functionName}:process:file.FullName=$($file.FullName)"

		if ($file.Exists -and -not $Force) {
			throw "File $($File.Name) already exists.  Use -Force to overwrite."
		}

		if (-not $file.Directory.Exists) {
			Write-Debug "${functionName}:process:Creating output directory $($file.Directory.FullName)"
			$file.Directory.Create()
		}
        
		Write-Debug "${functionName}:begin:End"
	}

	process {
		Write-Debug "${functionName}:process:Start"

		[string]$json = Get-AppConfigValues -ConfigStore $ConfigStore -AsJson
		Write-Debug "${functionName}:process:json=$json"

		Write-Debug "${functionName}:process:Writing to $($file.FullName):"
		Set-Content -Path $file.FullName -Value $json -Force
		$file.Refresh()
		Write-Output $file

		Write-Debug "${functionName}:process:End"
	}

	end {
		Write-Debug "${functionName}:end:Start"
		Write-Debug "${functionName}:end:End"
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
		Write-Debug "${functionName}:begin:Start"
		Write-Debug "${functionName}:begin:ConfigStore=$ConfigStore"
		Write-Debug "${functionName}:begin:Label=$Label"
		Write-Debug "${functionName}:begin:End"
	}
    
	process {
		Write-Debug "${functionName}:process:Start"

		Write-Verbose "Getting list of config entries from $ConfigStore"

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

		Write-Debug "${functionName}:process:command=$command"
       
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

		Write-Debug "${functionName}:process:End"
	}

	end {
		Write-Debug "${functionName}:end:Start"
		Write-Debug "${functionName}:end:End"
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
		Write-Debug "${functionName}:begin:Start"
		Write-Debug "${functionName}:begin:End"
	}

	process {
		Write-Debug "${functionName}:process:Start"
		Write-Debug "${functionName}:process:Path=$Path"

		[System.IO.FileInfo]$file = $Path
		Write-Debug "${functionName}:process:file.FullName=$($file.FullName)"

		if (-not $file.Exists) {
			throw [System.IO.FileNotFoundException]::new($file.FullName)
		}

		[string]$content = Get-Content -Path $Path

		Write-Debug "${functionName}:process:content=$content"

		$output = $content | ConvertFrom-Json | ConvertTo-AppConfigEntry | Sort-Object -Property Key, Label

		Write-Output $output

		Write-Debug "${functionName}:process:End"
	}

	end {
		Write-Debug "${functionName}:end:Start"
		Write-Debug "${functionName}:end:End"
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

  .PARAMETER DeleteEntriesNotInFile
    This switch enables the removal of any entry that isn't contained in the import file.  

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
		[switch]$DeleteEntriesNotInFile
	)

	begin {
		[string]$functionName = $MyInvocation.MyCommand
		Write-Debug "${functionName}:begin:Start"
		Write-Debug "${functionName}:begin:ConfigStore=$ConfigStore"
		Write-Debug "${functionName}:begin:Label=$Label"
		Write-Debug "${functionName}:begin:Path=$Path"

		[array]$outputs = @()
		[System.IO.FileInfo]$importFile = $Path

		if (-not $importFile.Exists) {
			throw [System.IO.FileNotFoundException]::new($importFile.FullName)
		}

		Write-Debug "${functionName}:begin:End"
	}

	process {
		Write-Debug "${functionName}:process:Start"

		[AppConfigEntry[]]$existingItems = Get-AppConfigValues -ConfigStore $ConfigStore -Label $Label
		[AppConfigEntry[]]$desiredItems = Get-AppConfigValuesFromFile -Path $importFile.FullName
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

		Write-Debug "${functionName}:process:End"
	}

	end {
		Write-Debug "${functionName}:end:Start"

		if ($outputs.Count -gt 0) {
			[AppConfigEntry[]]$results = $outputs | ConvertFrom-Json | ConvertTo-AppConfigEntry
			Write-Output $results
		}

		Write-Debug "${functionName}:end:End"
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
		Write-Debug "${functionName}:begin:Start"
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
         
		Write-Debug "${functionName}:begin:End"
	}

	process {
		Write-Debug "${functionName}:process:Start"

		$sourceAppConfig.Keys | ForEach-Object {
			Write-Debug "${functionName}:process:sourceKey=$_"
			[AppConfigEntry]$sourceItem = $SourceAppConfig[$_]
			if ($destinationAppConfig.ContainsKey($_)) {
				[AppConfigEntry]$destinationItem = $destinationAppConfig[$_]
				[string]$sourceValue = $sourceItem.Value
				[string]$sourceContentType = $sourceItem.ContentType
				[string]$destinationValue = $destinationItem.Value
				[string]$destinationContentType = $destinationItem.ContentType
				[bool]$same = `
				($sourceValue -ceq $destinationValue) `
					-and `
				(
                        ([string]::IsNullOrWhiteSpace($sourceContentType) -and [string]::IsNullOrWhiteSpace($destinationContentType)) `
						-or 
                        ($sourceContentType -ceq $destinationContentType)
				)
				Write-Debug "${functionName}:process:${same}:sourceValue/destinationValue=${sourceValue}/${destinationValue}"

				if (-not $same) {
					Write-Debug "${functionName}:process:$_ differs - needs updated"
					$updateEntries.Add($_, $sourceItem)
				}
			}
			else {
				Write-Debug "${functionName}:process:$_ not found in destination"
				$addEntries.Add($_, $sourceItem)
			}
		}

		$destinationAppConfig.Keys | ForEach-Object {
			[bool]$exists = $sourceAppConfig.ContainsKey($_)
			Write-Debug "${functionName}:process:${exists}:destinationKey=$_"

			if (-not $exists) {
				Write-Verbose "$_ surplus - needs removed"
				$removeEntries.Add($_, $destinationAppConfig[$_])
			}
		}

		Write-Debug "${functionName}:process:End"
	}

	end {
		Write-Debug "${functionName}:end:Start"

		[AppConfigDifferences]$differences = [AppConfigDifferences]::new()
		$differences.Add = $addEntries.Values
		$differences.Update = $updateEntries.Values
		$differences.Remove = $removeEntries.Values

		Write-Output $differences
        
		Write-Debug "${functionName}:end:End"
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
		Write-Debug "${functionName}:begin:Start"
		Write-Debug "${functionName}:begin:ConfigStore=$ConfigStore"
		Write-Debug "${functionName}:begin:End"
	}
    
	process {
		Write-Debug "${functionName}:process:Start"
		Write-Debug "${functionName}:process:InputObject.Key=$($InputObject.Key)"
		Write-Debug "${functionName}:process:InputObject.Label=$($InputObject.Label)"

		[string]$label = $InputObject.Label
		[string]$key = $InputObject.Key

		[System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az appconfig kv delete --auth-mode login --yes ")
		[void]$commandBuilder.Append(" --name `"$ConfigStore`" ")
		[void]$commandBuilder.Append(" --key `"$key`" ")

		if (-not [string]::IsNullOrWhiteSpace($label)) {
			[void]$commandBuilder.Append(" --label `"$label`" ")
		}

		[string]$command = $commandBuilder.ToString()

		Write-Debug "${functionName}:process:command=$command"
		Write-Verbose "Removing ${key}:${label} from $ConfigStore"

		if ($PSCmdlet.ShouldProcess($command, $ConfigStore, $functionName)) {
			[string]$output = Invoke-Expression -Command $command 
			[int]$processExitCode = $LASTEXITCODE
			Write-Output $output
			if ($processExitCode -ne 0) {
				throw "'$command' exited with non-zero exit code '$processExitCode'"
			}
		}
		Write-Debug "${functionName}:process:End"
	}

	end {
		Write-Debug "${functionName}:end:Start"
		Write-Debug "${functionName}:end:End"
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
		Write-Debug "${functionName}:begin:Start"
		Write-Debug "${functionName}:begin:ConfigStore=$ConfigStore"
		Write-Debug "${functionName}:begin:End"
	}
    
	process {
		Write-Debug "${functionName}:process:Start"
		Write-Debug "${functionName}:process:InputObject.Key=$($InputObject.Key)"
		Write-Debug "${functionName}:process:InputObject.Label=$($InputObject.Label)"
		Write-Debug "${functionName}:process:InputObject.Value=$($InputObject.Value)"
		Write-Debug "${functionName}:process:InputObject.ContentType=$($InputObject.ContentType)"

		[string]$key = $InputObject.Key
		[string]$label = $InputObject.Label
		[string]$contentType = $InputObject.ContentType
		[bool]$isKeyVault = $InputObject.IsKeyVault()

		Write-Debug "${functionName}:process:isKeyVault=$isKeyVault"

		[System.Text.StringBuilder]$commandBuilder = [System.Text.StringBuilder]::new("az appconfig kv ")
		if ($isKeyVault) {
			[void]$commandBuilder.Append(" set-keyvault ")
			[string]$secretIdentifier = $InputObject.GetSecretIdentifier()
			[void]$commandBuilder.Append(" --secret-identifier `"$secretIdentifier`" ")
		} 
		else {
			[void]$commandBuilder.Append(" set ")
			[void]$commandBuilder.Append(" --value `"$($InputObject.Value)`" ")
			if ([string]::IsNullOrWhiteSpace($contentType)) {
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

		Write-Debug "${functionName}:process:command=$command"

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
		Write-Debug "${functionName}:process:End"
	}

	end {
		Write-Debug "${functionName}:end:Start"
		Write-Debug "${functionName}:end:End"
	}
}
