[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $searchServicesName,
    [string] $apikey,    
    [string] $Name,
    [string] $ConfigDataFolderPath,
    [string]$WorkingDirectory = $PWD
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
Write-Debug "${functionName}:searchServicesName=$searchServicesName"
Write-Debug "${functionName}:ConfigDataFolderPath=$ConfigDataFolderPath"
Write-Debug "${functionName}:WorkingDirectory=$WorkingDirectory"

Function Set-AzureSearchObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ApiKey,
        [Parameter(Mandatory = $true)][string]$SearchServicesName,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source
    )
    Write-Host "Creating/ Updating Datasource $Name for Search Service $SearchServicesName"
    $body = Get-Content -Raw -Path $Source | ConvertFrom-Json
    
    $body.name = $Name
 
    $bodyText = ConvertTo-Json -InputObject $body -Compress -Depth 20

    $headers = @{
        "Authorization" = "Bearer $($ApiKey)"
        "Content-Type"  = "application/json"
    }
    $ApiVersion = "2024-05-01-Preview"
    $url = "https://$($SearchServicesName).search.windows.net/$($Type)/$($Name)/?api-version=$($ApiVersion)"
 
    Invoke-RestMethod -Uri $url -ContentType "application/json" -Headers $headers -Method Put -Body $BodyText -UseBasicParsing
}

try {
    if ($null -eq $ConfigDataFolderPath) {
        throw "One of the parameter 'ConfigDataFolderPath' is required."
    }

    [System.IO.DirectoryInfo]$moduleDir = Join-Path -Path $WorkingDirectory -ChildPath "templates/powershell/modules/ps-helpers"
    Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
    Import-Module $moduleDir.FullName -Force

    $dirNames = @('datasources', 'indexes', 'skillsets', 'indexers')
    ForEach ($dir in $dirNames) {    
        $Files = Get-ChildItem -Path "$($ConfigDataFolderPath)/$dir"
        ForEach ($File in $Files) {            
            Set-AzureSearchObject -Type $dir -Name $($File.Basename) -Source $($File.FullName) -SearchServicesName $searchServicesName -ApiKey $apikey            
        }
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
