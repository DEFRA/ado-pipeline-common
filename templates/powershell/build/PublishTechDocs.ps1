<#
.SYNOPSIS
Generate and Publish techdocs for backstage app
.DESCRIPTION
Generate and Publish techdocs for backstage app
.PARAMETER StorageAccountName
Mandatory. Storage account to publish the tech docs
.PARAMETER ContainerName
Optional. Name of the storage container
.PARAMETER ComponentName
Optional. Name of the comnponent
.PARAMETER ResourceGroup
Optional. Resource Group
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module

.EXAMPLE
.\PublishTechDocs.ps1 -StorageAccountName <StorageAccountName> -ContainerName <ContainerName> -ComponentName <ComponentName> -ResourceGroup <ResourceGroup> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$StorageAccountName,
    [Parameter(Mandatory)]
    [string]$ContainerName = "techdocs",
    [Parameter(Mandatory)]
    [string]$ComponentName,
    [Parameter(Mandatory)]
    [string]$ResourceGroup,
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
Write-Output "${functionName}:Command=$StorageAccountName"
Write-Output "${functionName}:ContainerName=$ContainerName"
Write-Output "${functionName}:ComponentName=$ComponentName"
Write-Output "${functionName}:ResourceGroup=$ResourceGroup"
Write-Output "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {
     
    Import-Module $PSHelperDirectory -Force   

    [string]$entity = "default/component/" + $ComponentName
    [string]$siteDir = "site" 
    $storageAccountkey = Invoke-CommandLine -Command "(az storage account keys list -g $ResourceGroup -n $StorageAccountName | ConvertFrom-Json)[0].value"
    #New-Item -Path "." -Name $siteDir -ItemType "directory"
    Invoke-CommandLine -Command "npm install -g @techdocs/cli" 
    Invoke-CommandLine -Command "pip3 install mkdocs-techdocs-core" 
    #Following command expects the source to be in docs directory and generates the site folder     
    Invoke-CommandLine -Command "techdocs-cli generate --no-docker --source-dir . --output-dir $siteDir"
    Invoke-CommandLine -Command "az storage container create -n $ContainerName --account-name $StorageAccountName"
    Invoke-CommandLine -Command "techdocs-cli publish --publisher-type azureBlobStorage --azureAccountName $StorageAccountName --storage-name $ContainerName --entity $entity --azureAccountKey $storageAccountkey --directory $siteDir"    
    
    Write-Output "${functionName}:Publish Complete" 
       
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