<#
    .SYNOPSIS
       This script checks for mandatory properties in the environments parameter
    .DESCRIPTION
       The script validates against a list of mandatory properties the Consumer pipeline must provide in the environments parameter.
       It also checks the Consumer has only provided 1 developmentEnvironment property which is set to True
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory = $true)]
    [string]$Environments
)

$environmentsHashTable = $Environments | ConvertFrom-Json -AsHashtable

$developmentEnvironmentCount = ($environmentsHashTable.developmentEnvironment | Where-Object { $_ -eq "True" }).Count

if ($developmentEnvironmentCount -ne 1) {
    throw "You must provide only 1 development environment."
}

$mandatoryEnvironmentProperties = @('serviceConnection','azureRegions')

$whatIfallowedValues = 'Skip', 'RunWithPause', 'RunWithoutPause'

$ValidationErrors = @()
foreach ($environment in $environmentsHashTable) {
    if (-not $environment.ContainsKey('name')) {
        throw "Environment must contain 'name' property."
    }

    if ($environment.developmentEnvironment -eq "True" -and [array]::IndexOf($environmentsHashTable, $environment) -gt 0) {
        $ValidationErrors += "Environment '$($environment.name)': developmentEnvironment must be the first environment in the environments object."
    }

    if ($environment.useDevelopmentEnvironmentForValidationOnly -eq "True" -and [array]::IndexOf($environmentsHashTable, $environment) -gt 0) {
        $ValidationErrors += "Environment '$($environment.name)': useDevelopmentEnvironmentForValidationOnly can only be used alongside developmentEnvironment in the first environment in the environments object."
    }

    if ($environment.developmentEnvironment -eq "True" -and $environment.name.ToUpper() -eq 'PRD') {
        $ValidationErrors += "Environment '$($environment.name)': Production cannot be a Development Environment."
    }

    if ($environment.outputTemplateChange -and (-not $whatIfallowedValues.Contains($environment.outputTemplateChange))) {
        $ValidationErrors += "Environment '$($environment.name)': environment.outputTemplateChange accepts the following values 'Skip', 'RunWithPause', 'RunWithoutPause'."
    }

    $missingProperties = @()
    foreach ($mandatoryProperty in $mandatoryEnvironmentProperties) {
        if (-not $environment.ContainsKey($mandatoryProperty)) {
            $missingProperties += $mandatoryProperty
        }
    }

    if ($missingProperties.Count -gt 0) {
        $ValidationErrors += "Environment '$($environment.name)': must contain '$($missingProperties -join ',')' properties.`n"
    }

    #Create Array for User Input regions
    $azurePrimaryAndSecondaryRegions = @()
    #primary is mandatory
    if ((-not $environment.azureRegions.ContainsKey('primary'))) {
        $ValidationErrors  += "Environment '$($environment.name)': 'primary' must be the first property in azureRegions object."
    }
    else {
        $azurePrimaryAndSecondaryRegions += $environment.azureRegions['primary']
    }
    
    #secondary is optional
    if ($environment.azureRegions.ContainsKey('secondary')) {
        foreach ($secondaryregion in $environment.azureRegions['secondary']){
            $azurePrimaryAndSecondaryRegions += $secondaryregion
        }
    }

    $validAzureRegions = @('NorthEurope', 'WestEurope', 'UKSouth', 'UKWest')
    $invalidAzureRegions = @()
    foreach ($inputRegion in $azurePrimaryAndSecondaryRegions){
        if ((-not [string]::IsNullOrEmpty($inputRegion)) -and -not ($validAzureRegions -contains $inputRegion)){
            $invalidAzureRegions += $inputRegion
        } 
    }

    if ($invalidAzureRegions.Count -gt 0){
        $ValidationErrors += "Environment '$($environment.name)': Invalid regions provided : $($invalidAzureRegions -join ','). Allowed regions are : $($validAzureRegions -join ',')." 
    }
}    

if ($ValidationErrors.Count -gt 0) {
    $errorlist = "Validation Erros: `n"
    $errorlist +=  $ValidationErrors -join "`n"
    Write-Error $errorlist
    throw "Validation failed for Environment object."
}
else {
    Write-Output "Validation for Environment object has passed."
}