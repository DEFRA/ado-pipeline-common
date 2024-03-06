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
.PARAMETER PSHelperDirectory
Mandatory. Directory Path of PSHelper module


.EXAMPLE
.\ListAndImportSecretsToKV.ps1  -VariableGroups <VariableGroups> -EnvName <EnvName> -ProgrammeName <ProgrammeName> 
    -AppKeyVault <AppKeyVault> -VarFilter <VarFilter>  -PSHelperDirectory <PSHelperDirectory> 
#> 

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VariableGroups,
    [Parameter(Mandatory)]
    [string]$EnvName,     
    [string]$ProgrammeName,         
    [Parameter(Mandatory)]
    [string]$AppKeyVault,        
    [string]$VarFilter,    
    [Parameter(Mandatory)]
    [string]$PSHelperDirectory
)


function ImportSecretsToKV {
    param(
        [Parameter(Mandatory)]
        [string]$KeyVault,
        [Parameter(Mandatory)]
        [string]$secretName
    )
    begin {
        [string]$functionName = $MyInvocation.MyCommand
        Write-Debug "${functionName}:Entered"
        Write-Debug "${functionName}:KeyVault=$KeyVault"
        Write-Debug "${functionName}:secretName=$secretName"
    }
    process {

        $pipelineVarEnc = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($secretName)"))
        write-output $pipelineVarEnc
        write-output [System.Text.Encoding]::UTF8.GetBytes("$($secretName)")

        $decodedValue = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pipelineVarEnc))

        try {

            Write-Host "Get the secret($secretName) from KeyVault $KeyVault"
            $oldValue = Invoke-CommandLine -Command "az keyvault secret show --name $secretName --vault-name $KeyVault | convertfrom-json"
            Write-Host "Secret($secretName) length:$($oldValue.Length)"
        }
        catch {
            $oldValue = $null
        }        

        if (($null -eq $oldValue) -or ($oldValue.value -ne $decodedValue)) {
            Write-Host "Set the secret($secretName) to KeyVault $KeyVault"
            Invoke-CommandLine -Command "az keyvault secret set --name $secretName --vault-name $KeyVault --value '$decodedValue'" -IsSensitive > $null
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
Write-Debug "${functionName}:VariableGroups=$VariableGroups"
Write-Debug "${functionName}:EnvName=$EnvName"
Write-Debug "${functionName}:ProgrammeName=$ProgrammeName"
Write-Debug "${functionName}:AppKeyVault=$AppKeyVault"
Write-Debug "${functionName}:VarFilter=$VarFilter"
Write-Debug "${functionName}:PSHelperDirectory=$PSHelperDirectory"

try {

    Import-Module $PSHelperDirectory -Force

    Invoke-CommandLine -Command "az devops configure --defaults organization=$ENV:DevOpOrganization"
    Invoke-CommandLine -Command "az devops configure --defaults project=$ENV:DevOpsProject"
    $VariableGroupsArray = $VariableGroups -split ";"
    if (![string]::IsNullOrEmpty($VarFilter)) {
        $VarFilterArray = $VarFilter -split ";"
    } 
    foreach ($VariableGroup in $VariableGroupsArray) {
        if ([string]::IsNullOrEmpty($ProgrammeName) -or $VariableGroup -like $ProgrammeName -or $VariableGroup -match $ProgrammeName) {        
            if ($VariableGroup.Contains('<environment>')) {
                $VariableGroup = $VariableGroup -replace '<environment>', $EnvName
            }
            if ($VariableGroup.Contains($EnvName)) {
                Write-Host "VariableGroup :$VariableGroup"                  
                $group = Invoke-CommandLine -Command "az pipelines variable-group list --group-name $VariableGroup --detect true | ConvertFrom-Json"            
                $groupId = $group.id
                $variable_group = Invoke-CommandLine -Command "az pipelines variable-group variable list --group-id $groupId --detect true  | ConvertFrom-Json"  
                $variables = $variable_group.psobject.Properties.Name
                Write-Host "variables :$variables" 
                foreach ($variable in $variables) {
                    if (![string]::IsNullOrEmpty($VarFilterArray)) {
                        foreach ($filter in $VarFilterArray) {
                            if ($variable -like $filter -or $variable -match $filter) {      
                                $variablesArray += $variable             
                                #ImportSecretsToKV -KeyVault $AppKeyVault -secretName $variable
                                continue
                            }
                            else {
                                Write-Debug "Variable :$variable does not match with filter :$filter"  
                            }
                        }
                    }
                    else {                  
                        $variablesArray += $variable
                        #ImportSecretsToKV -KeyVault $AppKeyVault -secretName $variable
                    }
                }

                Write-Host "variablesArray :$variablesArray" 
                
            }
            else {
                Write-Host "${functionName} :$VariableGroup not related to env: $EnvName"        
            }
        }
        else {
            Write-Host "VariableGroup :$VariableGroup does not match with ProgrammeName :$ProgrammeName"  
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

