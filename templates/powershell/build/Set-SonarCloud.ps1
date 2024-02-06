[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepositoryName,
    [Parameter(Mandatory)]
    [string]$KeyVaultName,
    [Parameter()]
    [string]$keyVaultSecretName = 'sonar-api-key',
    [Parameter()]
    [string]$SonarOrganisation = 'defra'
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
Write-Debug "${functionName}:RepositoryName=$RepositoryName"
Write-Debug "${functionName}:KeyVaultName=$KeyVaultName"
Write-Debug "${functionName}:SonarOrganisation=$SonarOrganisation"

try {
    $sonarUrl = "https://sonarcloud.io"

    Write-Debug "Reading SonarCloud API key from '$KeyVaultName' KeyVault..."
    [string]$sonarKey = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $keyVaultSecretName -AsPlainText -ErrorAction Stop
    $sonarKey += ":"
    [string]$encodedText = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($sonarKey))

    $headers = @{
        "Authorization" = "Basic $encodedText"
        "Accept"        = "application/json"
    }

    Write-Debug "Checking existence of the project '$RepositoryName'..."
    [Object]$response = Invoke-RestMethod -Method Get -Uri "$sonarUrl/api/components/search_projects?organization=$SonarOrganisation&filter=query+%3D+%22$RepositoryName%22" -Headers $headers

    if ($response -and $response.components.Count -le 0) {
        Write-Output "Creating project '$RepositoryName' on '$SonarOrganisation' organisation."
        Invoke-RestMethod -Method Post -Uri "$sonarUrl/api/projects/create" -Headers $headers -Body "name=$RepositoryName&project=$RepositoryName&organization=$SonarOrganisation&visibility=public&newCodeDefinitionType=previous_version"

        Write-Debug "Renaming default branch of the project '$RepositoryName' to 'main'."
        Invoke-RestMethod -Method Post -Uri "$sonarUrl/api/project_branches/rename" -Headers $headers -Body "project=$RepositoryName&name=main"
    }
    else {
        Write-Output "The project '$RepositoryName' already exists on '$SonarOrganisation' organisation."
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
