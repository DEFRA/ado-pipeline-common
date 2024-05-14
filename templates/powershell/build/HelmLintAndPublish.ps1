<#
.SYNOPSIS
Helm lint and/or publish using Azure Service Connection
.DESCRIPTION
Helm lint and/or publish using Azure Service Connection
.PARAMETER AcrName
Optional. Azure Container Registry used to push the helm chart
.PARAMETER ChartVersion
Optional. Chart Version 
.PARAMETER ChartCachePath
Mandatory. Chart Cache Path on the build agent
.PARAMETER Command
Optional. Command to run, lint, lintandbuild, build or publish or Default = lint 
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.PARAMETER chartHomeDir
Mandatory. Directory Path of all helm charts
.PARAMETER KeyVaultVSecretNames
Optional. Keyvault Secret Names in string format
.PARAMETER ServiceName
Optional. Service Name

.EXAMPLE
.\HelmLintAndPublish.ps1  AcrName <AcrName> ChartVersion <ChartVersion> ChartCachePath <ChartCachePath> Command <Command>  PSHelperDirectory <PSHelperDirectory> chartHomeDir <chartHomeDir> 
-KeyVaultVSecretNames <KeyVaultVSecretNames> -ServiceName <ServiceName>
#> 

[CmdletBinding()]
param(
    [string] $AcrName,
    [string] $ChartVersion,
    [string] $ChartCachePath = ".",
    [string] $Command = "lint",
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [Parameter(Mandatory)]
    [string]$chartHomeDir,
    [string]$KeyVaultVSecretNames = "[]",
    [string]$ServiceName
)


function Update-KVSecretValues {
    param(
        [Parameter(Mandatory)]
        [string]$InfraChartHomeDir,
        [Parameter(Mandatory)]
        [string]$ServiceName,
        [Parameter(Mandatory)]
        [string]$KeyVaultVSecretNames
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:InfraChartHomeDir=$InfraChartHomeDir"
        Write-Debug "${functionName}:ServiceName=$ServiceName"
        Write-Debug "${functionName}:KeyVaultVSecretNames=$KeyVaultVSecretNames"
    }
    process {
        if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
            Write-Host "powershell-yaml Module does not exists. Installing now.."
            Install-Module powershell-yaml -Force
            Write-Host "powershell-yaml Installed Successfully."
        } 
        else {
            Write-Host "powershell-yaml Module exist"
        }

        $kvSecretNames = $KeyVaultVSecretNames | ConvertFrom-Json

        Write-Debug "${functionName}:kvSecretNames:$kvSecretNames"
    
        $valuesYamlPath = "$InfraChartHomeDir\values.yaml"
        [string]$content = Get-Content -Raw -Path $valuesYamlPath
        Write-Debug "$valuesYamlPath content before: $content"
        if($content) {
            $valuesObject = ConvertFrom-YAML $content -Ordered
            # This condition is to initialize '$valuesObject' when values.yaml files contains only comments and not any values(Possible scenario).
            if(-not $valuesObject) {
                $valuesObject = [ordered]@{}
            }
        }
        else {
            $valuesObject = [ordered]@{}
        }

        $keyVaultSecrets = [System.Collections.Generic.List[hashtable]]@()
        foreach ($secret in $kvSecretNames) {
                
            #Logic to remove servicename from the secretname
            #for e.g. "ffc-demo-payment-web-COOKIE-PASSWORD" will get replace with "COOKIE-PASSWORD"
            if ($secret -like "$ServiceName*") {
                $NoOfStartingCharsToTrunk = $ServiceName.Length + 1
                $secretWithoutServiceName = $secret.subString($NoOfStartingCharsToTrunk, ($secret.Length - $NoOfStartingCharsToTrunk) )
            }
            else {
                $secretWithoutServiceName = $secret
            }

            $roleAssignments = [System.Collections.Generic.List[hashtable]]@()
            $roleAssignments.Add(@{
                    roleName = "keyvaultsecretuser"
                })

            $keyVaultSecrets.Add(@{
                    name            = $secretWithoutServiceName
                    roleAssignments = $roleAssignments
                })
        }

        $valuesObject.Add("keyVaultSecrets", $keyVaultSecrets)

        Write-Host "Converting valuesObject to yaml and writing it to file : $valuesYamlPath"
        $output = Convertto-yaml $valuesObject
        Write-Debug "$valuesYamlPath content after: $output"
        $output | Out-File $valuesYamlPath
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Invoke-HelmLint {
    param(
        [Parameter(Mandatory)]
        [string]$HelmChartName
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:HelmChartName=$HelmChartName"
    }
    process {
        Write-Host "Build Helm dependencies for $HelmChartName"
        try {
            Invoke-CommandLine -Command "helm dependency build"
        }
        catch {
            Invoke-CommandLine -Command "helm dependency update"
        }

        Write-Host "Linting Helm chart $HelmChartName"
        Invoke-CommandLine -Command "helm lint"
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Invoke-HelmValidateAndBuild {
    param(
        [Parameter(Mandatory)]
        [string]$HelmChartName,
        [Parameter(Mandatory)]
        [string]$ChartVersion,
        [Parameter(Mandatory)]
        [string]$PathToSaveChart,
        [string]$ValuesYamlString = "" 
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:HelmChartName=$HelmChartName"
        Write-Debug "${functionName}:ChartVersion=$ChartVersion"
        Write-Debug "${functionName}:PathToSaveChart=$PathToSaveChart"
        Write-Debug "${functionName}:ValuesYamlString=$ValuesYamlString"  # Log new parameter

        $tempFile = $null

        if ($ValuesYamlString -ne "") {
            $tempFile = New-TemporaryFile
            $ValuesYamlString | Out-File -FilePath $tempFile.FullName
        }
    }
    process {
        try {
            Invoke-CommandLine -Command "helm dependency build"
        }
        catch {
            Invoke-CommandLine -Command "helm dependency update"
        }
        
        Invoke-CommandLine -Command "helm lint ."

        if ($null -ne $tempFile) {  
            Invoke-CommandLine -Command "helm template . --values $($tempFile.FullName)"
        }
        else {
            Invoke-CommandLine -Command "helm template . 2>&1"
        }

        Invoke-CommandLine -Command "helm package . --version $ChartVersion"

        Write-Host "Saving chart '$HelmChartName-$ChartVersion.tgz' to $ChartCachePath"
        Copy-Item "$helmChartName-$ChartVersion.tgz" -Destination $ChartCachePath -Force 
    }
    end {
        Write-Debug "${functionName}:Exited"
        if ($null -ne $tempFile) {  
            Remove-Item -Path $tempFile.FullName -Force
        }
    }
}

function Invoke-HelmBuild {
    param(
        [Parameter(Mandatory)]
        [string]$HelmChartName,
        [Parameter(Mandatory)]
        [string]$ChartVersion,
        [Parameter(Mandatory)]
        [string]$PathToSaveChart
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:HelmChartName=$HelmChartName"
        Write-Debug "${functionName}:ChartVersion=$ChartVersion"
        Write-Debug "${functionName}:PathToSaveChart=$PathToSaveChart"
    }
    process {
        try {
            Invoke-CommandLine -Command "helm dependency build"
        }
        catch {
            Invoke-CommandLine -Command "helm dependency update"
        }
        
        Invoke-CommandLine -Command "helm package . --version $ChartVersion"

        Write-Host "Saving chart '$HelmChartName-$ChartVersion.tgz' to $ChartCachePath"
        Copy-Item "$helmChartName-$ChartVersion.tgz" -Destination $ChartCachePath -Force 
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Invoke-Publish {
    param(
        [Parameter(Mandatory)]
        [string]$HelmChartName,
        [Parameter(Mandatory)]
        [string]$ChartVersion,
        [Parameter(Mandatory)]
        [string]$PathToSaveChart
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:HelmChartName=$HelmChartName"
        Write-Debug "${functionName}:ChartVersion=$ChartVersion"
        Write-Debug "${functionName}:PathToSaveChart=$PathToSaveChart"
    }
    process {
        Write-Host "Publishing Helm chart $HelmChartName"
        $acrHelmPath = "oci://$AcrName.azurecr.io/helm"
        if (Test-Path $PathToSaveChart -PathType Leaf) { 

            Write-Host "Publising cached chart $acrHelmPath from $PathToSaveChart"
            Invoke-CommandLine -Command "helm push $PathToSaveChart $acrHelmPath"
        }
        else {                                   
            Write-Host "Chart does not exist in cache. Publishing chart $acrHelmPath from current directory" 
            throw "Chart does not exist in cache"         
        }
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

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
Write-Debug "${functionName}:AcrName=$AcrName"
Write-Debug "${functionName}:ChartVersion=$ChartVersion"
Write-Debug "${functionName}:ChartCachePath=$ChartCachePath"
Write-Debug "${functionName}:Command=$Command"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Debug "${functionName}:chartHomeDir=$chartHomeDir"
Write-Debug "${functionName}:KeyVaultVSecretNames=$KeyVaultVSecretNames"
Write-Debug "${functionName}:ServiceName=$ServiceName"

try {

    Import-Module $PSHelperDirectory -Force

    $InfraChartDirName = "$serviceName-infra"
    #If there are no variable groups for given service the KeyVaultVSecretNames value will be "$(secretVariableNamesJson)"
    if ($KeyVaultVSecretNames.Contains("secretVariableNamesJson")) {
        $KeyVaultVSecretNames = "[]"
    }
    $helmChartsDirList = Get-ChildItem -Path $chartHomeDir

    $helmChartsDirList | ForEach-Object {

        $helmChartName = $_.Name
        Write-Debug "${functionName}:helmChartName=$helmChartName"

        $chartDirectory = Get-ChildItem -Recurse -Path $(Join-Path -Path $chartHomeDir -ChildPath $helmChartName)  -Include Chart.yaml | Where-Object { $_.PSIsContainer -eq $false }
        if ($chartDirectory) {
            Write-Debug "${functionName}:Changing location to $($chartDirectory.DirectoryName)"
            Push-Location $chartDirectory.DirectoryName
            Write-Debug "${functionName}:Current location is '$(Get-Location)'"
        
            Write-Host "Working on Chart: $helmChartName in directory: $chartDirectory"
            $chartCacheFilePath = Join-Path -Path $ChartCachePath -ChildPath "$helmChartName-$ChartVersion.tgz"
            Write-Debug "${functionName}:chartCacheFilePath=$chartCacheFilePath"
    
            if (!(Test-Path $ChartCachePath -PathType Container)) {
                New-Item -ItemType Directory -Force -Path $ChartCachePath
                Write-Host "Created Chart Cache Path: $ChartCachePath"
            }
                
            switch ($Command.ToLower()) {
                'lint' {
                    Invoke-HelmLint -HelmChartName $helmChartName
                }
                'build' {                    
                    Invoke-HelmBuild -HelmChartName $helmChartName -ChartVersion $ChartVersion -PathToSaveChart $ChartCachePath
                }
                'lintandbuild' {

                    if ($chartDirectory.DirectoryName.Contains($InfraChartDirName)) {                
                        Write-Host "Adding 'keyvault-secrets-role-assignment.yaml' file to $chartHomeDir\$InfraChartDirName/templates folder"
                        '{{- include "adp-aso-helm-library.keyvault-secrets-role-assignment" . -}}' | Out-File -FilePath "$chartHomeDir/$InfraChartDirName/templates/keyvault-secrets-role-assignment.yaml"
                    }

                    Invoke-HelmValidateAndBuild -HelmChartName $helmChartName -ChartVersion $ChartVersion -PathToSaveChart $ChartCachePath
                }
                'publish' {

                    if ($chartDirectory.DirectoryName.Contains($InfraChartDirName)) {  
                        #Update KeyVault Secret Names in values.yaml file of infrastruture helm chart
                        if ((Test-Path $chartCacheFilePath -PathType Leaf) -and (-not $KeyVaultVSecretNames.Equals("[]"))) { 
                            Invoke-CommandLine -Command "tar zxf $chartCacheFilePath -C $ChartCachePath"
                            Remove-Item $chartCacheFilePath
                            Update-KVSecretValues -InfraChartHomeDir "$ChartCachePath/$InfraChartDirName" -ServiceName $ServiceName -KeyVaultVSecretNames $KeyVaultVSecretNames
                            Push-Location $ChartCachePath
                            Invoke-CommandLine -Command "tar czf $chartCacheFilePath $InfraChartDirName"
                        }                                                
                    }

                    Invoke-CommandLine -Command "az acr login --name $AcrName"
                    Invoke-Publish -HelmChartName $helmChartName -ChartVersion $ChartVersion -PathToSaveChart $chartCacheFilePath
                }
                
            }
        }
        else {
            Write-Host "ChartDirectory does not exit for $helmChartName."
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
    Pop-Location
}

