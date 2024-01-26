<#
.SYNOPSIS
Generate and Publish techdocs for backstage app
.DESCRIPTION
Generate and Publish techdocs for backstage app
.PARAMETER Command
Optional. Build or Publish
.PARAMETER StorageAccountName
Optional. Storage account to publish the tech docs
.PARAMETER ContainerName
Optional. Name of the storage container
.PARAMETER EntityName
Optional. Name of the entity default/component/adp
.PARAMETER ResourceGroup
Optional. Resource Group
.PARAMETER SitePath
Mandatory. Generated Site Path
.PARAMETER PSHelperDirectory
Optional. Directory Path of PSHelper module

.EXAMPLE
.\PublishTechDocs.ps1 -Command <Command> -StorageAccountName <StorageAccountName> -ContainerName <ContainerName> -EntityName <EntityName> -ResourceGroup <ResourceGroup> -SitePath <SitePath> -PSHelperDirectory <PSHelperDirectory>
#> 

[CmdletBinding()]
param(
    [string]$Command = "Build",
    [string]$StorageAccountName,
    [string]$ContainerName = "techdocs",
    [string]$EntityName,
    [string]$ResourceGroup,
    [Parameter(Mandatory)]
    [string]$SitePath,
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
Write-Output "${functionName}:Command=$Command"
Write-Output "${functionName}:StorageAccountName=$StorageAccountName"
Write-Output "${functionName}:ContainerName=$ContainerName"
Write-Output "${functionName}:EntityName=$EntityName"
Write-Output "${functionName}:ResourceGroup=$ResourceGroup"
Write-Output "${functionName}:SitePath=$SitePath"
Write-Output "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {
  
    npm install -g @techdocs/cli --loglevel=error
    
    python3 -m venv venv
    ./venv/bin/activate
    pip3 install mkdocs-material --no-warn-script-location
    pip3 install pillow cairosvg --no-warn-script-location
    pip3 install mkdocs-glightbox --no-warn-script-location
    pip3 install mkdocs-nav-weight --no-warn-script-location
    pip3 install mkdocs-techdocs-core --no-warn-script-location

    if ("Build" -eq $Command) {
        #Following command expects the mkdocs.yml to be in current directory and generates the site folder             
        techdocs-cli generate --no-docker --source-dir . --output-dir $SitePath
    }
    elseif ("Publish" -eq $Command) {
        Import-Module $PSHelperDirectory -Force  
        Invoke-CommandLine -Command "az storage container create -n $ContainerName --account-name $StorageAccountName"
        $storageAccountkey = Invoke-CommandLine -Command "(az storage account keys list -g $ResourceGroup -n $StorageAccountName | ConvertFrom-Json)[0].value"
        techdocs-cli publish --publisher-type azureBlobStorage --azureAccountName $StorageAccountName --storage-name $ContainerName --entity $EntityName --azureAccountKey $storageAccountkey --directory $SitePath
    }            
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