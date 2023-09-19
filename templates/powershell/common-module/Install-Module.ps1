param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,
    [Parameter(Mandatory = $true)]
    [string]$ModuleName ,
    [Parameter(Mandatory = $false)]
    [string]$ModuleVersion

)

$token = $env:SYSTEM_ACCESSTOKEN | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($env:SYSTEM_ACCESSTOKEN, $token)

Write-Host "Request to install ModuleName = $ModuleName and ModuleVersion = $ModuleVersion"

if (-not [string]::IsNullOrWhitespace($ModuleVersion)) {
    Write-Host "Installing $ModuleName module of version $ModuleVersion..."
    Install-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Repository $RepositoryName -Scope CurrentUser -Credential $credential -Force -SkipPublisherCheck
} 
else {
    Write-Host "Installing default $ModuleName module..."
    Install-Module -Name $ModuleName -Repository $RepositoryName -Scope CurrentUser -Credential $credential -Force -SkipPublisherCheck
}

Write-Host "Module InstalledLocation : " (Get-InstalledModule -Name $ModuleName).InstalledLocation