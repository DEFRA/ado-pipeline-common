[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ApiBaseUri,
    [Parameter(Mandatory)]
    [string]$TeamName,
    [Parameter(Mandatory)]
    [string]$ServiceName,
    [Parameter(Mandatory)]
    [string]$EnvName
)

function Add-Environment {
    param (
        [Parameter(Mandatory)]
        [string]$ApiBaseUri,
        [Parameter(Mandatory)]
        [string]$TeamName,
        [Parameter(Mandatory)]
        [string]$ServiceName,
        [Parameter(Mandatory)]
        [string]$Name
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:ApiBaseUri=$ApiBaseUri"
        Write-Debug "${functionName}:TeamName=$TeamName"
        Write-Debug "${functionName}:ServiceName=$ServiceName"
        Write-Debug "${functionName}:Name=$Name"
    }
    process {
        $uri = "$ApiBaseUri/FluxTeamConfig/$TeamName/services/$ServiceName/environments"
        Write-Debug "${functionName}:Uri=$uri"

        Invoke-RestMethod -Uri $uri -Method Post -Body (@($Name) | ConvertTo-Json) -ContentType "application/json"
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Add-FluxConfig {
    param (
        [Parameter(Mandatory)]
        [string]$ApiBaseUri,
        [Parameter(Mandatory)]
        [string]$TeamName,
        [Parameter(Mandatory)]
        [string]$ServiceName
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:ApiBaseUri=$ApiBaseUri"
        Write-Debug "${functionName}:TeamName=$TeamName"
        Write-Debug "${functionName}:ServiceName=$ServiceName"
    }
    process {
        $uri = "$ApiBaseUri/FluxTeamConfig/$TeamName/generate?serviceName=$ServiceName"
        Write-Debug "${functionName}:Uri=$uri"
        
        Invoke-RestMethod -Uri $uri -Method Post
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
Write-Debug "${functionName}:TeamName=$TeamName"
Write-Debug "${functionName}:ServiceName=$ServiceName"
Write-Debug "${functionName}:EnvName=$EnvName"

try {
    Write-Host "Adding environment '$EnvName' to service '$ServiceName' for team '$TeamName'"
    Add-Environment -ApiBaseUri $ApiBaseUri -TeamName $TeamName -ServiceName $ServiceName -Name $EnvName 

    Write-Host "Generating flux config for service '$ServiceName' for team '$TeamName'"
    Add-FluxConfig -ApiBaseUri $ApiBaseUri -TeamName $TeamName -ServiceName $ServiceName

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