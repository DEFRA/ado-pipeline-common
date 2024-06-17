[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ApiBaseUri,
    [Parameter(Mandatory)]
    [string]$TeamName,
    [Parameter(Mandatory)]
    [string]$ServiceName,
    [Parameter(Mandatory)]
    [string]$EnvName,
    [Parameter(Mandatory)]
    [string]$KeyVaultName,
    [Parameter(Mandatory)]
    [string]$TenantId
)

function Invoke-FluxApi {
    param (
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [string]$Method,
        [object]$Body
    )

    begin {
        [string]$functionName = $MyInvocation.MyCommand.Name
        Write-Debug "${functionName}:Entered"
        $headers = @{
            "Authorization" = "Bearer $accessToken"
        }
        $contentType = "application/json"
    }
    process {
        Write-Debug "${functionName}:Uri=$Uri"
        Write-Debug "${functionName}:Method=$Method"
        Write-Debug "${functionName}:Body=$Body"

        $jsonBody = if ($Body) { $Body | ConvertTo-Json -Depth 5 } else { $null }

        return Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -Body $jsonBody -ContentType $contentType
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Get-ApiAccessToken {
    param (
        [Parameter(Mandatory)]
        [string]$KeyVaultName,
        [Parameter(Mandatory)]
        [string]$TenantId
    )

    begin {
        [string]$functionName = $MyInvocation.MyCommand.Name
        Write-Debug "${functionName}:Entered"
        $secretNames = @("ADOCALLBACK-API-CLIENT-APP-REG-CLIENT-ID", "ADOCALLBACK-API-CLIENT-APP-REG-CLIENT-SECRET", "API-AUTH-BACKEND-APP-REG-CLIENT-ID")
        $secrets = @{}
    }
    process {
        Write-Debug "${functionName}:KeyVaultName=$KeyVaultName"
        Write-Debug "${functionName}:TenantId=$TenantId"

        foreach ($name in $secretNames) {
            Write-Debug "${functionName}:Getting secret $name"
            $secrets[$name] = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $name -AsPlainText -ErrorAction Stop -Debug:$false).Trim()
        }

        $reqTokenBody = @{
            Grant_Type    = "client_credentials"
            Scope         = "api://$($secrets["API-AUTH-BACKEND-APP-REG-CLIENT-ID"])/.default"
            client_Id     = $secrets["ADOCALLBACK-API-CLIENT-APP-REG-CLIENT-ID"]
            Client_Secret = $secrets["ADOCALLBACK-API-CLIENT-APP-REG-CLIENT-SECRET"]
        }

        Write-Debug "${functionName}:Getting access token"
        $accessToken = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $reqTokenBody -ErrorAction Stop
        return $accessToken.access_token
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

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
    }
    process {
        Write-Debug "${functionName}:ApiBaseUri=$ApiBaseUri"
        Write-Debug "${functionName}:TeamName=$TeamName"
        Write-Debug "${functionName}:ServiceName=$ServiceName"
        Write-Debug "${functionName}:Name=$Name"

        $uri = "$ApiBaseUri/FluxTeamConfig/$TeamName/services/$ServiceName/environments"
        Write-Debug "${functionName}:Uri=$uri"
        
        Invoke-FluxApi -Uri $uri -Method Post -Body @($Name)
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Get-Environment {
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
        $uri = "$ApiBaseUri/FluxTeamConfig/$TeamName/services/$ServiceName/environments/$Name"
        Write-Debug "${functionName}:Uri=$uri"
        try {
            return Invoke-FluxApi -Uri $uri -Method Get 
        }
        catch {
            if ($null -ne $_.Exception.Response -and $_.Exception.Response.StatusCode -eq 404) {
                return $null
            } else {
                throw $_
            }
        }
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
        [string]$ServiceName,
        [Parameter(Mandatory)]
        [string]$EnvName
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
    }
    process {
        Write-Debug "${functionName}:ApiBaseUri=$ApiBaseUri"
        Write-Debug "${functionName}:TeamName=$TeamName"
        Write-Debug "${functionName}:ServiceName=$ServiceName"
        Write-Debug "${functionName}:EnvName=$EnvName"

        $uri = "$ApiBaseUri/FluxTeamConfig/$TeamName/generate?serviceName=$ServiceName&environment=$EnvName"
        Write-Debug "${functionName}:Uri=$uri"
       
        Invoke-FluxApi -Uri $uri -Method Post
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}

function Update-EnvironmentManifest {
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
    }
    process {
        Write-Debug "${functionName}:ApiBaseUri=$ApiBaseUri"
        Write-Debug "${functionName}:TeamName=$TeamName"
        Write-Debug "${functionName}:ServiceName=$ServiceName"
        Write-Debug "${functionName}:Name=$Name"

        $uri = "$ApiBaseUri/FluxTeamConfig/$TeamName/services/$ServiceName/environments/$Name/manifest"
        Write-Debug "${functionName}:Uri=$uri"

        return Invoke-FluxApi -Uri $uri -Method Patch -Body @({ generate=$false })
    }
    end {
        Write-Debug "${functionName}:Exited"
    }
}


Set-StrictMode -Version 3.0

[string]$functionName = $MyInvocation.MyCommand
[datetime]$startTime = [datetime]::UtcNow

[int]$exitCode = -1
[string]$accessToken = $null
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
Write-Debug "${functionName}:ApiBaseUri=$ApiBaseUri"
Write-Debug "${functionName}:KeyVaultName=$KeyVaultName"
Write-Debug "${functionName}:TenantId=$TenantId"

try {

    Write-Host "Generating flux manifest for service '$ServiceName' for team '$TeamName' in environment '$EnvName'"
    
    $accessToken = Get-ApiAccessToken -KeyVaultName $KeyVaultName -TenantId $TenantId
    
    $response = Get-Environment -ApiBaseUri $ApiBaseUri  -TeamName $TeamName -ServiceName $ServiceName -Name $EnvName
    $generate = $false
    
    if ($null -eq $response) {
        Add-Environment -ApiBaseUri $ApiBaseUri -TeamName $TeamName -ServiceName $ServiceName -Name $EnvName
    }
    elseif ($response.PSObject.Properties.Name -contains 'environment' -and $response.environment) {
        $generate = $null -eq $response.environment.manifest ? $true : $response.environment.manifest.generate -or ($response.environment.manifest.generatedVersion -lt $response.fluxTemplatesVersion)
    }
    
    if ($null -eq $response -or $generate) {
        Add-FluxConfig -ApiBaseUri $ApiBaseUri -TeamName $TeamName -ServiceName $ServiceName -EnvName $EnvName
        Update-EnvironmentManifest -ApiBaseUri $ApiBaseUri -TeamName $TeamName -ServiceName $ServiceName -Name $EnvName
    }
    
    Write-Host "Flux manifest generated successfully."
    
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