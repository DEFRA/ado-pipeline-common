<#
.SYNOPSIS
List all variables from provided list of groups
.DESCRIPTION
List all variables from provided list of groups

.PARAMETER VariableGroups
Mandatory. SemiColon seperated variable groups
.PARAMETER ProgrammeName
Mandatory. ProgrammeName Name
.PARAMETER EnvName
Mandatory. Environment Name
.PARAMETER VarFilter
Optional. SemiColon seperated variable filters defaults to *
.PARAMETER AppKeyVault
Mandatory. appKeyVault Name
.PARAMETER ServiceConnection
Mandatory. serviceConnection Name
.PARAMETER PrivateAgentName
Mandatory. PrivateAgent Name
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module
.PARAMETER BuildNumber

.EXAMPLE
.\ListSecrets.ps1  -VariableGroups <VariableGroups> -EnvName <EnvName> -ProgrammeName <ProgrammeName> -ServiceConnection <ServiceConnection> 
    -AppKeyVault <AppKeyVault> -VarFilter <VarFilter>  -PrivateAgentName <PrivateAgentName> -PSHelperDirectory <PSHelperDirectory> -BuildNumber <BuildNumber>
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VariableGroups,
    [Parameter(Mandatory)]
    [string]$EnvName,     
    [string]$ProgrammeName,   
    [Parameter(Mandatory)]  
    [string]$ServiceConnection,         
    [Parameter(Mandatory)]
    [string]$AppKeyVault,        
    [string]$VarFilter,    
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory,
    [Parameter(Mandatory)]
    [string]$PrivateAgentName,
    [Parameter(Mandatory)]
    [string]$BuildNumber
)


function GetPipelineBuildStatus {
    param(
        [Parameter(Mandatory)]
        [string]$buildQueueId,
        [Parameter(Mandatory)]
        [string]$organization,
        [Parameter(Mandatory)]
        [string]$project
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:buildQueueId=$buildQueueId"
        Write-Debug "${functionName}:organization=$organization"
        Write-Debug "${functionName}:project=$project"
    }
    process {
        if ($null -ne $buildQueueId) {
            # Get the status of triggered build
            $buildDetails = Invoke-CommandLine -Command "(az pipelines build show --id $buildQueueId --detect true --organization $organization --project $project) | ConvertFrom-Json"   

            while ($buildDetails.status -ne "completed") {
                Start-Sleep -Seconds 10
                if ($buildDetails.status -eq "notStarted") {
                    Write-Host $buildDetails.status -ForegroundColor Green
                }
                if ($buildDetails.status -eq "canceled") {
                    Write-Error "The build number $buildQueueId is $buildDetails.status"
                }
                # Get the status of the triggered build again
                $buildDetails = Invoke-CommandLine -Command "(az pipelines build show --id $buildQueueId --detect true --organization $organization --project $project) | ConvertFrom-Json"   
                if ($buildDetails.status -eq "failed") {
                    Write-Error "The build number $buildQueueId is $buildDetails.status"   
                    throw "Import Secrets Build Failed"
                }
            }		
           
        }
        
        return $buildDetails
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
Write-Debug "${functionName}:VariableGroups=$VariableGroups"
Write-Debug "${functionName}:EnvName=$EnvName"
Write-Debug "${functionName}:ProgrammeName=$ProgrammeName"
Write-Debug "${functionName}:AppKeyVault=$AppKeyVault"
Write-Debug "${functionName}:VarFilter=$VarFilter"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"
Write-Debug "${functionName}:ServiceConnection=$ServiceConnection"
Write-Debug "${functionName}:privateAgentName=$PrivateAgentName"

try {

    Import-Module $PSHelperDirectory -Force

    $variablesArray = @()

    Invoke-CommandLine -Command "az devops configure --defaults organization=$ENV:DevOpOrganization"
    Invoke-CommandLine -Command "az devops configure --defaults project=$ENV:DevOpsProject"
    $VariableGroupsArray = $VariableGroups -split ";"
    if ([string]::IsNullOrEmpty($VarFilter)) {
        $VarFilter = "*"
    }
    else {
        $VarFilter = $VarFilter -split ";"
    } 
    if ([string]::IsNullOrEmpty($ProgrammeName)) {
        $ProgrammeName = "*"
    }  
    foreach ($VariableGroup in $VariableGroupsArray) {
        if ($VariableGroup -like $ProgrammeName) {        
            if ($VariableGroup -like '<environment>') {
                $VariableGroup = $VariableGroup -replace '<environment>', $EnvName
            }
            if ($VariableGroup -like $EnvName) {
                Write-Host "${functionName} :$VariableGroup"                  
                $group = Invoke-CommandLine -Command "az pipelines variable-group list  --group-name $VariableGroup --detect true | ConvertFrom-Json"            
                $groupId = $group.id
                $variable_group = Invoke-CommandLine -Command "az pipelines variable-group variable list --group-id $groupId --detect true  | ConvertFrom-Json"  
                $variables = $variable_group.psobject.Properties.Name
                Write-Host "variables :$variables" 
                foreach ($variable in $variables) {
                    foreach ($filter in $VarFilter) {
                        if ($variable -like $filter) {
                            $variablesArray += $variable
                            continue
                        }
                    }
                }
                if ($variablesArray.Length -gt 0) {
                    $variablesArrayString = $variablesArray -join ';'  
                    Write-Debug "variablesArrayString :$variablesArrayString"
                    $command = "az pipelines run --project $ENV:DevOpsProject --name $ENV:ImportPipelineName --branch $ENV:ImportPipelineBranch"
                    $prameters = " --parameters 'secretNames=$variablesArrayString' 'variableGroups=$VariableGroup' 'serviceConnection=$ServiceConnection' 'appKeyVault=$AppKeyVault' 'privateAgentName=$PrivateAgentName' "
                    $prameters = $prameters + " 'buildNumber=$BuildNumber' 'project=$ENV:DevOpsProject' 'organization=$ENV:DevOpOrganization'"
                    $buildQueue = Invoke-CommandLine -Command " $command $prameters  | ConvertFrom-Json" 
                    Write-Debug "buildQueue :$buildQueue"
                    Write-Host $buildQueue.url
                    GetPipelineBuildStatus -buildQueueId $buildQueue.id -organization $ENV:DevOpOrganization -project $ENV:DevOpsProject
                }
            }
            else {
                Write-Host "${functionName} :$VariableGroup not related to env: $EnvName"        
            }
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

