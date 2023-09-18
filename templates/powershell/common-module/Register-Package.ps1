param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName,
    [Parameter(Mandatory = $true)]
    [string]$PackageFeedEndpoint

)

#Print Pre-Dependecies require to install module successfully
$powerShellGetDetails = Get-Module -Name PowerShellGet
Write-Host "PowerShellGet Version on this system: $($powerShellGetDetails)"
$packageManagementDetails = Get-Module -Name PackageManagement
Write-Host "PackageManagement Version on this system: $($packageManagementDetails)"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 

$token = $env:SYSTEM_ACCESSTOKEN | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($env:SYSTEM_ACCESSTOKEN, $token)

Write-Host "Check if PackageSource exist for RepositoryName = $RepositoryName and PackageFeedEndpoint = $PackageFeedEndpoint"
$packageSource = Get-PackageSource -Name $RepositoryName -ErrorAction Ignore | Where-Object { $_.Location -eq $($PackageFeedEndpoint) }
Write-Host "packageSource = $packageSource"
if (-not $packageSource) {
    Write-Host "Excecuting Register-PackageSource for Repository $RepositoryName.."
    Register-PackageSource -Name $RepositoryName -Location $PackageFeedEndpoint -ProviderName PowerShellGet -Trusted -Credential $credential
}
else {
    Write-Host "PackageSource $RepositoryName  with location $PackageFeedEndpoint already exit. Register-PackageSource step skiped"
}

Write-Host "Printing Get-PSRepository after Register-PackageSource step.."
Get-PSRepository -Name $RepositoryName | Format-List
Get-PackageSource -Name $RepositoryName | Format-List