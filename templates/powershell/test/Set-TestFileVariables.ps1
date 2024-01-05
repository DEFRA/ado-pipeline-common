<#
.SYNOPSIS

.DESCRIPTION

.PARAMETER WorkingDirectory
Mandatory. Directory Path of Service

.EXAMPLE

#> 

[CmdletBinding()]
param(
    [Parameter()]
    [string]$WorkingDirectory = $PWD
)

# $WorkingDirectory = 'C:\ganesh\projects\defra\repo\github\Defra\ffc-demo-web'

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
        Write-Output "##vso[task.setvariable variable=hasHelmChart]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=hasHelmChart]false"
    }

    #'./docker-compose.test.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.test.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_test_yaml]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_test_yaml]false"
    }

    #'./docker-compose.acceptance.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.acceptance.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_acceptance_yaml]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_acceptance_yaml]false"
    }

    #'./docker-compose.zap.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.zap.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_zap_yaml]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_zap_yaml]false"
    }

    #'./docker-compose.pa11y.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.pa11y.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_pa11y_yaml]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_pa11y_yaml]false"
    }

    #'./docker-compose.axe.yaml'
    if(Test-Path -Path "$WorkingDirectory/docker-compose.axe.yaml"){
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_axe_yaml]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=docker_compose_dot_axe_yaml]false"
    }

    #'./test/acceptance/docker-compose.yaml'
    if(Test-Path -Path "$WorkingDirectory/test/acceptance/docker-compose.yaml"){
        Write-Output "##vso[task.setvariable variable=test_acceptance_docker_compose_dot_yaml]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=test_acceptance_docker_compose_dot_yaml]false"
    }

    #'./test/performance/docker-compose.jmeter.yaml'
    if(Test-Path -Path "$WorkingDirectory/test/performance/docker-compose.jmeter.yaml"){
        Write-Output "##vso[task.setvariable variable=test_performance_docker_compose_dot_jmeter_yaml]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=test_performance_docker_compose_dot_jmeter_yaml]false"
    }

    #'./test/performance/jmeterConfig.csv'
    if(Test-Path -Path "$WorkingDirectory/test/performance/jmeterConfig.csv"){
        Write-Output "##vso[task.setvariable variable=test_performance_jmeterConfig_dot_csv]true"
    }
    else{
        Write-Output "##vso[task.setvariable variable=test_performance_jmeterConfig_dot_csv]false"
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