<#
.SYNOPSIS
Set flags for docker test files.

.DESCRIPTION
Set flags for docker test files if it exists in the service repository.
Below variables are set to true if file exists,

docker_compose_dot_test_yaml = "./docker-compose.test.yaml"
docker_compose_dot_acceptance_yaml = "./docker-compose.acceptance.yaml"
docker_compose_dot_zap_yaml = "./docker-compose.zap.yaml"
docker_compose_dot_pa11y_yaml = "./docker-compose.pa11y.yaml"
docker_compose_dot_axe_yaml = "./docker-compose.axe.yaml"
test_acceptance_docker_compose_dot_yaml = "./test/acceptance/docker-compose.yaml"
test_performance_jmeterConfig_dot_csv = "./test/performance/jmeterConfig.csv"

.PARAMETER WorkingDirectory
Mandatory. Directory Path of Service

.EXAMPLE

#> 

[CmdletBinding()]
param(
    [Parameter()]
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
Write-Debug "${functionName}:WorkingDirectory=$WorkingDirectory"

try {

    #'./helm/'
    if(Test-Path -Path "$WorkingDirectory/helm/"){
        Write-Output "##vso[task.setvariable variable=hasHelmChart;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=hasHelmChart;isOutput=true]false"
    }

    #'./docker-compose.test.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.test.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_test_yaml;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_test_yaml;isOutput=true]false"
    }

    #'./docker-compose.acceptance.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.acceptance.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_acceptance_yaml;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_acceptance_yaml;isOutput=true]false"
    }

    #'./docker-compose.zap.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.zap.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_zap_yaml;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_zap_yaml;isOutput=true]false"
    }

    #'./docker-compose.pa11y.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.pa11y.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_pa11y_yaml;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_pa11y_yaml;isOutput=true]false"
    }

    #'./docker-compose.axe.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.axe.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_axe_yaml;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_axe_yaml;isOutput=true]false"
    }

    #'./test/acceptance/docker-compose.yaml'
    if(Test-Path -Path "$WorkingDirectory/test/acceptance/docker-compose.yaml"){
        Write-Output "##vso[task.setvariable variable=test_acceptance_docker_compose_dot_yaml;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=test_acceptance_docker_compose_dot_yaml;isOutput=true]false"
    }

    #'./test/performance/docker-compose.jmeter.yaml'
    if(Test-Path -Path "$WorkingDirectory/test/performance/docker-compose.jmeter.yaml"){
        Write-Output "##vso[task.setvariable variable=test_performance_docker_compose_dot_jmeter_yaml;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=test_performance_docker_compose_dot_jmeter_yaml;isOutput=true]false"
    }

    #'./test/performance/jmeterConfig.csv'
    if(Test-Path -Path "$WorkingDirectory/test/performance/jmeterConfig.csv"){
        Write-Output "##vso[task.setvariable variable=test_performance_jmeterConfig_dot_csv;isOutput=true]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=test_performance_jmeterConfig_dot_csv;isOutput=true]false"
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