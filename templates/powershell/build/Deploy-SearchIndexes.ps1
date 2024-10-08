<#
.SYNOPSIS
Deploy Search Indexes to Azure Search Service
.DESCRIPTION
Deploy Search Indexes to Azure Search Service
.PARAMETER ServiceName
Mandatory. Name of the Service
.PARAMETER TeamName
Mandatory. Name of the Team
.PARAMETER SearchServiceName
Mandatory. Name of the Search Service
.PARAMETER ServiceResourceGroup
Mandatory. Name of the Resource Group
.PARAMETER ConfigDataFolderPath
Optional. Search service configuration data folder path
.PARAMETER PSHelperDirectory
Optional. Path to the PS Helper module directory
.EXAMPLE
.\Deploy-SearchIndexes.ps1  -ServiceName <ServiceName> -TeamName <TeamName> -SearchServiceName <SearchServiceName> -ServiceResourceGroup <ServiceResourceGroup> -ConfigDataFolderPath <ConfigDataFolderPath> -PSHelperDirectory -<PSHelperDirectory> 
#> 


[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServiceName,
    [Parameter(Mandatory)]
    [string]$TeamName,
    [Parameter(Mandatory)]
    [string]$SearchServiceName,
    [Parameter(Mandatory)]
    [string]$ServiceResourceGroup,
    [Parameter(Mandatory)]
    [string]$ConfigDataFolderPath,
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory
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
Write-Debug "${functionName}:ServiceName=$ServiceName"
Write-Debug "${functionName}:TeamName=$TeamName"
Write-Debug "${functionName}:searchServiceName=$SearchServiceName"
Write-Debug "${functionName}:ServiceResourceGroup=$ServiceResourceGroup"
Write-Debug "${functionName}:ConfigDataFolderPath=$ConfigDataFolderPath"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

Function Set-RBAC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServiceName,
        [Parameter(Mandatory = $true)][string]$TeamName,
        [Parameter(Mandatory = $true)][string]$SearchServiceName,
        [Parameter(Mandatory = $true)][string]$ServiceResourceGroup,
        [Parameter(Mandatory = $true)][array]$AccessList
    )   
    $teamRG = $ServiceResourceGroup + "-" + $TeamName
    $miPrincipalId = az identity list -g $teamRG --query "[?contains(name,'$ServiceName')].{principalId: principalId}" | ConvertFrom-Json
    if ($null -eq $miPrincipalId ) {
        throw "Managed Identity not found for $ServiceName in $teamRG"
    }
    
    $searchservice = az search service show -n $SearchServiceName -g $ServiceResourceGroup | ConvertFrom-Json
    if ($null -eq $searchservice ) {
        throw "Search Service not found in $ServiceResourceGroup"
    }
    $AccessList | ForEach-Object {
        $indexResourceId = $searchservice.id + "/indexes/" + $_.name
        $Role = $_.role
        if ($Role -eq "Contributor") {
            $role = "Search Index Data Contributor"
        }
        elseif ($Role -eq "Reader") {
            $role = "Search Index Data Reader"
        }
        else {
            throw "Invalid Role $Role"
        }  
        az role assignment create --assignee-object-id $miPrincipalId.principalId --assignee-principal-type ServicePrincipal --role $Role --scope $indexResourceId
    }    
}

Function Set-AzureSearchObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Token,
        [Parameter(Mandatory = $true)][string]$SearchServiceName,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Source
    )   
    $body = Get-Content -Raw -Path $Source | ConvertFrom-Json    
    $body.name = $Name
    $bodyText = ConvertTo-Json -InputObject $body -Compress -Depth 20

    $headers = @{
        "Authorization" = "Bearer $($Token)"
        "Content-Type"  = "application/json"
    }
    $ApiVersion = "2024-05-01-Preview"
    $url = "https://$($SearchServiceName).search.windows.net/$($Type)/$($Name)/?api-version=$($ApiVersion)"
    Write-Host "calling $url"
    Invoke-RestMethod -Uri $url -ContentType "application/json" -Headers $headers -Method Put -Body $BodyText -UseBasicParsing
}

try {
    if ($null -ne $ConfigDataFolderPath) {
        [System.IO.DirectoryInfo]$moduleDir = $PSHelperDirectory
        Write-Debug "${functionName}:moduleDir.FullName=$($moduleDir.FullName)"
        Import-Module $moduleDir.FullName -Force
        
        $token = Invoke-CommandLine -Command "az account get-access-token --scope https://search.azure.com/.default"
        $accessToken = ($token | ConvertFrom-Json).accessToken

        $dirNames = @('datasources', 'indexes', 'skillsets', 'indexers')
        ForEach ($dir in $dirNames) {
            if (Test-Path -Path "$($ConfigDataFolderPath)/$dir") {
                $Files = Get-ChildItem -Path "$($ConfigDataFolderPath)/$dir"
                ForEach ($File in $Files) {
                    if ($($File.Basename) -match $TeamName) {
                        Set-AzureSearchObject -Type $dir -Name $($File.Basename) -Source $($File.FullName) -SearchServiceName $SearchServiceName -Token $accessToken                        
                    }
                    else {
                        Write-Host "Skipping $($File.Basename) as it does not match the team name $TeamName"
                    }                    
                }
            }
            else {
                Write-Host "No $dir found in $ConfigDataFolderPath"
            }
        }

        if (Test-Path -Path "$($ConfigDataFolderPath)/access.json") {
            $accessList = Get-Content -Raw -Path "$($ConfigDataFolderPath)/access.json" | ConvertFrom-Json
            if ($null -ne $accessList) {  
                Set-RBAC -ServiceName $ServiceName -TeamName $TeamName -SearchServiceName $SearchServiceName -ServiceResourceGroup $ServiceResourceGroup -AccessList $accessList
            }
            else {
                throw "No access list found in access.json"
            }
        }
        else {
            throw "No access.json found in $ConfigDataFolderPath"
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
