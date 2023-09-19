param(
    [Parameter(Mandatory = $true)]
    [string] $TemplateFile
)

$errortests = @(
    'JSONFiles-Should-Be-Valid',
    'DeploymentTemplate-Schema-Is-Correct',
    'Parameters-Must-Be-Referenced',
    'Secure-String-Parameters-Cannot-Have-Default',
    'DeploymentTemplate-Must-Not-Contain-Hardcoded-Uri',
    'adminUsername-Should-Not-Be-A-Literal',
    'Outputs-Must-Not-Contain-Secrets')

$warningtests = @('DependsOn-Best-Practices',
    'Location-Should-Not-Be-Hardcoded',
    'VM-Size-Should-Be-A-Parameter',
    'Deployment-Resources-Must-Not-Be-Debug',
    'Dynamic-Variable-References-Should-Not-Use-Concat',
    'IDs-Should-Be-Derived-From-ResourceIDs',
    'ManagedIdentityExtension-must-not-be-used',
    'Min-And-Max-Value-Are-Numbers',
    'Parameter-Types-Should-Be-Consistent',
    'Parameters-Must-Be-Referenced',
    'Password-params-must-be-secure',
    'ResourceIds-should-not-contain',
    'Resources-Should-Have-Location',
    'Secure-Params-In-Nested-Deployments',
    'Template-Should-Not-Contain-Blanks',
    'URIs-Should-Be-Properly-Constructed',
    'Variables-Must-Be-Referenced',
    'artifacts-parameter',
    'providers_apiVersions-Is-Not-Permitted'
    'DeploymentParameters-Should-Have-Value',
    'DeploymentParameters-Should-Have-Schema',
    'DeploymentParameters-Should-Have-Parameters',
    'DeploymentParameters-Should-Have-ContentVersion')

$armTtkModule = Join-Path -Path $PSScriptRoot -ChildPath "arm-template-toolkit" "arm-ttk" "arm-ttk.psd1"
Write-Host "Path: $armTtkModule"

if (-not(Test-Path -Path $armTtkModule -PathType Leaf)) {
    try {
        Write-Host "Downloading ARM ttk"
        $dowloadFilePath = Join-Path -Path $PSScriptRoot -ChildPath "arm-template-toolkit.zip"
        $extractTookKitPath = Join-Path -Path $PSScriptRoot -ChildPath "arm-template-toolkit"

        Invoke-WebRequest -Uri 'https://azurequickstartsservice.blob.core.windows.net/ttk/latest/arm-template-toolkit.zip' -OutFile $dowloadFilePath
        Expand-Archive -Path $dowloadFilePath -DestinationPath $extractTookKitPath -Force
        Write-Host "ARM ttk extracted"
    }
    catch {
        throw $_.Exception.Message
    }
}

Write-Host "Importing ARM ttk module"
Import-Module $armTtkModule

Write-Host  "##[group]Running ARM ttk tests on $TemplateFile - Error Tests"
Test-AzTemplate -TemplatePath $TemplateFile -Test $errortests -ErrorAction "Stop" 
Write-Host  "##[endgroup]"

Write-Host "##[group]Running ARM ttk tests on $TemplateFile - Warning Tests"
$warningTestRsults = Test-AzTemplate -TemplatePath $TemplateFile -Test $warningtests -ErrorAction "Continue"
Write-Output $warningTestRsults
Write-Host "##[endgroup]"

if ($warningTestRsults | Where-Object { $_.Errors || $_.Warnings }) {
    Write-Warning  "ARM ttk tests completed with warnings"
}
