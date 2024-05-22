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
    [string] GetSecretName() {
		[string]$result = $null
		if ($this.IsKeyVault()) {
			[hashtable]$item = ConvertFrom-Json -InputObject $this.Value -AsHashtable
			[string]$itemKey = $item.Keys[0]
			$uri = New-Object System.Uri($item[$itemKey])
            $result = $uri.Segments[2].TrimEnd('/')
		}
		return $result
	}
}