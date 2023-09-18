param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    [Parameter(Mandatory = $false)]
    [string]$ModuleVersion
)

if (-not [string]::IsNullOrWhitespace($ModuleVersion)) {
    Write-Host "UnInstalling $ModuleName module of version $ModuleVersion."
    Uninstall-Module -Name $ModuleName -RequiredVersion $ModuleVersion -Force -Confirm -ErrorAction Ignore
} 
else {
    Write-Host "UnInstalling $ModuleName module."
    Uninstall-Module -Name $ModuleName -Force -Confirm -ErrorAction Ignore
}
