[[_TOC_]]

# Scripts-only deployment pipeline
## Introduction
In this pipeline only runs scripts as part of the deployment. The intention here is to make the pipeline invocation strait forward for a scripts only approach. If you need infrastructure deployed via ARM or bicep templates use the [common-infrastructure-deploy.yaml](InfrastructureDeploy.md) pipeline-template instead.
## Usage

```yaml
resources:
  repositories:
    - repository: PipelineCommon
      name: DEFRA/ado-pipeline-common
      type: git
      ref: refs/tags/Release-v1-latest

extends:
  template: /templates/pipelines/common-scripts-deploy.yaml@PipelineCommon
  parameters:
    additionalRepositories: (optional)
      - <additional-repo1-name>
      - <additional-repo2-name>
    privateAgentName: <private agent pool name> (optional)
    agentImage: <Microsoft-hosted agent image name> (optional, default 'widows-latest')
    variableFiles:
      - /<scripts-vars-folder>/{environment}.yaml@self
    regionalVariableFiles:
      - /<scripts-vars-regional-folder>/{environment}-{region}.yaml@self
    environments:
      - name: 'dev' (required)
        userCustomVariables: <object of dynamically created key value pair variables and/or variable files reference> (optional)
        azureRegions:
          isSecondaryRegionDeploymentActive: false (optional, default is true)
          deployPrimaryAndSecondaryInParallel: true (optional, default is true)
          primary: <azure-primary-region>
          secondary:
          - <azure-secondary-region-1>
          - <azure-secondary-region-2>
        developmentEnvironment: True (optional but if provided it must be in the 1st environment in environments property)
        serviceConnection : <name of the service connection> (required))
        privateAgentName: <private agent pool name> (optional)
        agentImage: <Microsoft-hosted agent image name> (optional)
      - name: 'tst'
        userCustomVariables: <object of dynamically created key value pair variables and/or variable files reference> (optional)
        azureRegions:
          isSecondaryRegionDeploymentActive: true
          deployPrimaryAndSecondaryInParallel: true
          primary: <azure-primary-region>
          secondary:
          - <azure-secondary-region-1>
          - <azure-secondary-region-2>
        serviceConnection : <name of the service connection> (required)
        deploymentBranches:
          - 'refs/heads/integration'
          - 'refs/heads/main'
    deployFromFeature: false (toggle to override policy set in `deploymentBranches` and force deployment)
    filePathsForTransform: (optional)
      - <file-path>
    additionalRepositories: (optional)
     - <additional-repo1-name>
     - <additional-repo2-name>
    scriptsList:
      - displayName: <script-01-friendly-names>
        Type: <type> (optional, Avalibale values: AzurePowerShell, PowerShell, AzureCLI)
        azurePowershellUseCore: (optional, Applies when using `Type`: AzurePowerShell, PowerShell. Default is false)
        AzureCLIScriptType: (optional, Applies when using `Type`: AzureCLI. Avalible values: ps, pscore, batch, bash. Default is ps)
        useSystemAccessToken: (optional, default false)
        inlineScript: FunctionName -Arg01 <value-01> -Arg02 <value-02> (optional, Use either `inlineScript` or `scriptPath`)
        scriptPath: <relative-path>/scriptName-01.ps1 (optional, Use either `inlineScript` or `scriptPath`)
        scriptArguments: -Arg01 <value-01> -Arg02 <value-02> -Arg3 $(secretname) (Required when `scriptPath` is set)
        commonModulesToLoad: <List of Private modules to install from `defra-devops-common` package> (optional)
          - name: '<ModuleName>'
            version: '1.0.0'  (optional, Default version = Latest)
        failOnStandardError: true

      - displayName: <script-02-friendly-names>
        Type: <type> (optional, Avalibale values: AzurePowerShell, PowerShell, AzureCLI. Default: AzurePowerShell)
        azurePowershellUseCore: (optional, Applies when using `Type`: AzurePowerShell, PowerShell. Default is false)
        AzureCLIScriptType: (optional, Applies when using `Type`: AzureCLI. Avalible values: ps, pscore, batch, bash. Default is ps)
        useSystemAccessToken: (optional, default false)
        inlineScript: InlineFunction/Script -Arg01 <value-01> -Arg02 <value-02> (optional, Use either `inlineScript` or `scriptPath`)
        scriptPath: <relative-path>/scriptName-02.ps1 (optional, Use either `inlineScript` or `scriptPath`)
        scriptArguments: -Arg01 <value-01> -Arg02 <value-02> (Required when `scriptPath` is set)
        failOnStandardError: false

      - displayName: <script-03-friendly-names>
        Type: <type> (optional, Avalibale values: AzurePowerShell, PowerShell, AzureCLI. Default: AzurePowerShell)
        azurePowershellUseCore: (optional, Applies when using `type`: AzurePowerShell, PowerShell. Default is false)
        inlineScript: InlineFunction/Script -Arg01 <value-01> -Arg02 <value-02> (optional, Use either `inlineScript` or `scriptPath`)
        scriptPath: <relative-path>/scriptName-03.ps1 (optional, Use either `inlineScript` or `scriptPath`)
        scriptArguments: -Arg01 <value-01> -Arg02 <value-02> (Required when `scriptPath` is set)

```

> :warning: The shared pipeline repository is referred to a as `@PipelineCommon` also internally and therefore is a reserved repository name. If you need an additional repository resource use a different name (e.g. `@ProjectRepo`) as the repository names within the resources block need to be unique when the pipeline template is evaluated. The rational here is that the definition of the exact used resource sits in the consumer yaml file allowing for versioning via the `ref` (branch or tag). |


> :warning: You should always use latest tagged version (e.g. `refs/tags/Release-v6-latest`) in `ref` for `DEFRA-DEVOPS-COMMON/Defra.Pipeline.Common` repository. Main branch should not be used as this may change at any time and may contain breaking changes. The `DEFRA-DEVOPS-COMMON/Defra.Pipeline.Common` repository uses Semantic Versioning for version tagging. Breaking changes will result in a new release version while non-breaking changes will have the minor or patch version increased and can be referred to via the latest release tag.

Example of `script-deploy` project pipeline - https://dev.azure.com/defragovuk/DEFRA-DEVOPS-EXEMPLAR/_build?definitionId=1529

Example of Powershell package hosted in Artifact Feed - [GetHelloScript Powershell Nuget Package](https://dev.azure.com/defragovuk/DEFRA-DEVOPS-COMMON/_artifacts/feed/defra-devops-common/NuGet/GetHelloScript/overview/1.0.3)

Example of consuming module/feed project pipeline -
 - [scripts-only-pipeline-feed-consumer](https://dev.azure.com/defragovuk/DEFRA-DEVOPS-COMMON/_git/Defra.PowershellFeed.Consumer?path=/package-feed-consumer/azure-pipelines/scripts-only-pipeline-feed-consumer.yaml)
 - [infra-deploy-pipeline-feed-consumer](https://dev.azure.com/defragovuk/DEFRA-DEVOPS-COMMON/_git/Defra.PowershellFeed.Consumer?path=/package-feed-consumer/azure-pipelines/infra-deploy-pipeline-feed-consumer.yaml)

## Pipeline parameters

### privateAgentName/agentImage
`privateAgentName` and `agentImage` both define the agents used to run the pipeline. `privateAgentName` is used to set a self-hosted private agent pool, while `agentImage` is used to run the pipeline on Microsoft-hosted agents ([see full list of images](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml#software)). By default the pipeline deploys using Microsoft-hosted *'windows-latest'* image. `privateAgentName` or `agentImage` can be set either at the pipeline level (global) or at environment level (environment overwrite). If both `privateAgentName` and `agentImage` are set then `privateAgentName` takes precedence.

### additionalRepositories
A list of additional repositories you wish to check out. This is useful when you checkout multiple repositories and you want to access the assests or scripts in a deployment in later stages. Remember to ensure use the alias name when accessing the scripts

An example could look like this

  ```yaml
resources:
  repositories:
    - repository: PipelineCommon
      name: DEFRA-DEVOPS-COMMON/Defra.Pipeline.Common
      type: git
      ref: refs/tags/Release-v6-latest
    - repository: GIO_DATA_PLATFORM
      name: DEFRA-Common-Platform-Improvements/GIO_DATA_PLATFORM
      type: git
      ref: main
  
extends:
  template: /templates/pipelines/common-scripts-deploy.yaml@PipelineCommon
  parameters:
    additionalRepositories:
      -  GIO_DATA_PLATFORM
    variableFiles:
      - /vars/common.yaml@GIO_DATA_PLATFORM
      - /vars/{environment}.uksouth.yaml@GIO_DATA_PLATFORM
    environments:
      - name: 'DP_DEV'
        azureRegions:
          primary: uksouth
        developmentEnvironment: true
        deploymentBranches:
          - '*'
        serviceConnection: AZD-CPR-DEV1
    scriptsList:   
     - displayName: 'Configure Collections and Permissions'
       scriptPath: 'src/infrastructure/scripts/PowerShell/Purview/ConfigureCollections.ps1'
       type: AzurePowerShell
       scriptArguments: '-ConfigFilePath "$(Build.SourcesDirectory)/GIO_DATA_PLATFORM/src/config/catalogue/$(scriptEnvironment)" -Environment $(scriptEnvironment) -AccountName "$(scriptEnvironment)$(parent-project)$(nc-function-application)PV1001"'
```

### environments

`environments` required list of environments. The following are supported `dev`, `snd`, `tst`, `pre` and `prd`.

The Environments, by default run sequentially in the order which you defined them in the `environments` property.

There may be a situation in which a consumer may need to deploy to a non-standard environment e.g. training. As a result the consumer would have to create their own environment specific variable files /vars/training.yaml@self and add the training environment in the environments property. ( It is highly recommended to use the supported `dev`, `snd`, `tst`, `pre` and `prd`, unless absolutely necessary, such as a training environment.)

  ```yaml
  environments:
    - name: 'dev'
      developmentEnvironment: True
      azureRegions:
        isSecondaryRegionDeploymentActive: true
        primary: NorthEurope
        secondary:
        - WestEurope
      serviceConnection : <service -connection>
    - name: 'training'
      azureRegions:
        isSecondaryRegionDeploymentActive: false
        primary: NorthEurope
      serviceConnection : <service-connection>
  ```

#### azureRegions

`azureRegions` Provide the list of azure regions using `primary` and `secondary` property for each environment. The following are supported regions values : **northeurope**, **westeurope**, **uksouth** and **ukwest**

- `isSecondaryRegionDeploymentActive` (optional, default value `true`) Set it to false to skip the deployment for that environment in the secondary regions. This property takes effect only when `secondary` is supplied.
- `deployPrimaryAndSecondaryInParallel` (optional,  default value `true`) When true it runs the primary and secondary regions deployment jobs parallelly. Set it to false to run the primary and secondary regions deployment jobs sequencially.
- `primary` is mandatory and it should contain only single region which is the primary region for the deployment.
- `secondary` contains list of regions and more than one regions can be provided for deployment in the multiple secondary regions.

```yaml
  azureRegions:
    isSecondaryRegionDeploymentActive: true
    deployPrimaryAndSecondaryInParallel: true
    primary: NorthEurope
    secondary:
    - WestEurope
    - UKSouth
```

#### dependsOn/dependsOnAny

Using the `dependsOn`(optional), order of the environments is driven by dependsOn property. Pipelines must contain at least one environment with no dependencies.

To make an environment depend on the success of any of the previous ones is to combine `dependsOnAny` and `dependsOn` options. This allows the environment to run if either of the two preceding environments succeeds. However, this option is limited to two `dependsOn` environments at most.

The syntax for defining multiple environments and their dependencies with dependsOnAny is:

```yaml
environments:
   - name: 'dev'
     azureRegions:
       primary: NorthEurope
     developmentEnvironment: True
     serviceConnection : <service-connection>
   - name: 'tst_blue'
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
     serviceConnection : <service-connection>
     dependsOn: 'dev'
  - name: 'tst_green'
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
     serviceConnection : <service-connection>
     dependsOn: 'dev'
  - name: 'pre_blue'
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
     serviceConnection : <service-connection>
     dependsOnAny: True
     dependsOn: [tst_blue,tst_green]
  - name: 'pre_green'
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
     serviceConnection : <service-connection>
     dependsOnAny: True
     dependsOn: [tst_blue,tst_green]

```

#### deploymentBranches

Using the `deploymentBranches`(optional but highly recommended to set one that fit ones branching/deployment strategy), you can ensure the deployments to the environment are allowed only from the specified source branches. You can specify '*' to allow deployments from all branches. You can supply 'refs/pull/*/merge' for deployments triggered from a pull request policy.

The syntax for defining deploymentBranches for an environment is:

```yaml
 environments:
  - name: 'dev'
    developmentEnvironment: True
    azureRegions:
      isSecondaryRegionDeploymentActive: true
      deployPrimaryAndSecondaryInParallel: false
      primary: NorthEurope
      secondary:
      - WestEurope
    serviceConnection: <service-connection>
    deploymentBranches:
      - 'refs/heads/dev'
      - 'refs/heads/main'
```

#### developmentEnvironment

The `developmentEnvironment` property must be in the first environment defined in the 'environments' property.

#### keyVaultList

`keyVaultList` (optional, default value `[]`) List of Azure Key Vaults that is used to pull secrets from. When non-empty the `Name` field is mandatory. The items on the list can be configured individually with the following parameters:

- `Name` (required) Name of the Key Vault. Can be an ADO variable used as reference (see example below).
- `SecretsFilter` (optional, default value `'*'`) Comma-separated list of secrets to load from the given Key Vault. When missing this loads all secrets from a given Key Vault.
- `serviceConnection` (optional) The service connection used to access the Key Vault. When absent the environment service connection is used instead. This is useful when the Key Vault is in a different subscription than the environment where the templates are being deployed to. In the example below *serviceConnection2* is used instead of *serviceConnection1* for the second Key Vault.

```yaml
  environments:
    - name: "snd"
      deploymentBranches:
        - "*"
      developmentEnvironment: True
      azureRegions:
        primary: NorthEurope
      serviceConnection: serviceConnection1
      keyVaultList:
        - Name: $(KeyVault1.Name)
          SecretsFilter: "ExampleSecret02,ExampleSecret03"
        - Name: $(KeyVault2.Name)
          serviceConnection: serviceConnection2

```

> :pushpin: NOTE
In a rare case when the same secret name is used in multiple Azure Key Vaults then the last value is used overwriting the previous ones. If `keyVaultList` and `keyVaultName` are used at the same time, `keyVaultList` takes precedence over `keyVaultName`.

#### serviceConnection

`serviceConnection` (required) property defines the default ADO service connection used for the given environment. This is mandatory when you define environments.

#### userCustomVariables

The `userCustomVariables` (optional) are defined by consumers to pass dynamic parameters of type string as key value pair or variable file on pipeline run (see examples below).

**Example 1: defined as pipeline parameter.**

```yaml
  parameters:
  - name: customVariables
    displayName: "Custom Variables"
    type: object
    default:
    - name: varName
      value: 'test'
    - template: /path/to/vars/custom.yaml@self

    - name: 'tst'
      serviceConnection: AZD-CDO-TST1
      userCustomVariables: ${{ parameters.customVariables }}
 ```

**Example 2: defined as inline in environment object.**

```yaml
environments:
  - name: 'tst'
    enableTemplateValidationBeforeDeployment: true
    serviceConnection: AZD-CDO-TST1
    userCustomVariables:
      - name: testVar1
        value: $(environment)$(parameters.varName)
      - name: testVar2
        value: $(environment)$(parameters.varName)
      - template: /path/to/vars/custom.yaml@self
    azureRegions:
      isSecondaryRegionDeploymentActive: true
      deployPrimaryAndSecondaryInParallel: true
      primary: NorthEurope
      secondary:
      - WestEurope
    deploymentBranches:
    - '*'
  - name: 'snd'
    enableTemplateValidationBeforeDeployment: true
    serviceConnection: AZD-CDO-TST1
    userCustomVariables:
      - name: testVar1
        value: $(environment)$(parameters.varName)
      - name: testVar2
        value: $(environment)$(parameters.varName)
      - template: /path/to/vars/custom.yaml@self
    azureRegions:
      isSecondaryRegionDeploymentActive: true
      deployPrimaryAndSecondaryInParallel: true
      primary: NorthEurope
      secondary:
      - WestEurope
    deploymentBranches:
      - '*'
```

### deployFromFeature

`deployFromFeature` (optional, default value `false`) Toggle to override policy set in `deploymentBranches` and force deployment.

### variableFiles

`variableFiles` list of variables files to be loaded. It supports the following wildcard `{environment}` and will be replaced by the actual environment name at runtime.

Default list of files if nothing is set
```yaml
- /azure-pipelines/vars/common.yaml@self
- /azure-pipelines/vars/{environment}.yaml@self
```

| :warning: the source of the variable file must be indicated as a suffix, `@self` if in the same location as the yaml pipeline or the name of the separate repository (e.g. `@MyRepoName`) |
|:----------|

### regionalVariableFiles

`regionalVariableFiles` (optional) list of regional variable files to be loaded. It supports the following wildcard `{environment}` and `{region}` and will be replaced by the actual environment name and region code (e.g. `euw` for West Europe) at runtime. At the least the file path must contain wildcard `{region}`. Please use `variableFiles` if the variable file is not region specific.

By default no regional files are loaded.

For region specific variables please use the following example:
```yaml
- /azure-pipelines/vars/regional/{region}.yaml@self
```

In the case of deploying an environment in multiple regions the example below could be used to set values that are regional AND environment specific (e.g. set of IPs, VNETs or subnets)
```yaml
- /azure-pipelines/vars/regional/{environment}-{region}.yaml@self
```

| :warning: the source of the variable file must be indicated as a suffix, `@self` if in the same location as the yaml pipeline or the name of the separate repository (e.g. `@MyRepoName`) |
|:----------|

### additionalRepositories
`additionalRepositories` (optional) list of repositories to be checked out as part of the pipeline runs.
```yaml
additionalRepositories:
- Example-Repo-Name-1
- Example-Repo-Name-2
```

### scriptsList

`scriptsList` (required) A list of scripts to be executed in the pipeline.

#### type

`type` (optional, default value `AzurePowerShell`) Type of the Azure Devops task used for running the script. Supported values: `AzurePowerShell`, `PowerShell`, `AzureCLI`.

Example

```yaml
    scriptsList:
      - displayName: Dummy script 01
        scriptPath: deployscripts\dummyPowerShellScript.ps1
        scriptArguments: >
          -DummyParameter $(dummyVar)

      - displayName: MyScript
        scriptPath: scripts/AzureCLI.ps1
        type: AzureCLI

```

#### azurePowershellUseCore

`azurePowershellUseCore` (optional, default value `false`) Applies only when `type` is set to *AzurePowerShell* or *PowerShell*.

#### AzureCLIScriptType

`AzureCLIScriptType` (optional, default value `ps`) Applies when `type` is set to *AzureCLI*. Available values: *ps*, *pscore*, *batch*, *bash*.

#### inlineScript

`inlineScript` (optional) Defines an inline script. Use either `inlineScript` or `scriptPath`.

```yaml
inlineScript: FunctionName -Arg01 <value-01> -Arg02 <value-02>
```

#### scriptPath

`scriptPath` (optional) Defines a relative path to the script file. Use either `inlineScript` or `scriptPath`.

```yaml
scriptPath: <relative-path>/scriptName-01.ps1
```

#### scriptArguments

`scriptArguments` (required when `scriptPath` is set)

```yaml
scriptArguments: -Arg01 <value-01> -Arg02 <value-02> -Arg3 $(secretname)
```

#### commonModulesToLoad

`commonModulesToLoad` (optional) List of Private modules to install from `defra-devops-common` package.

- `name` - name of the module (required)
- `version` - module version (optional, Default version = Latest)

**Example 1 - latest somemodule and pined version of someothermodule**
```yaml
commonModulesToLoad:
  - name: somemodule
  - name: someothermodule
    version: '2.1.0'
```

#### failOnStandardError

`failOnStandardError` (optional, default value `false`) Flag to control whether the ADO task running the script should stop the pipeline while encountering a Standard Error.

#### useSystemAccessToken

Default is `false`. Setting this variable to 'true' allows use of '$env:SYSTEM_ACCESSTOKEN' variable inside script.

#### filePathsForTransform

`filePathsForTransform` is a list of files to parse and replace any occurrence of ADO variables with their values. ADO variables need to be wrapped in `#{{ }}`.

**Example 1 - Replace token and update file.**
`somefile.xml` is a template config file that will inject the values from ADO variables. The updated file is then feed into the script as na config.

```yaml
scriptsList:
  - displayName: Script01
    inlineScript: SomeScript -config relative-path/somefile.config
    filePathsForTransform:
      - relative-path/somefile.config
```

**Example 2 - File generation based on templates.**

```yaml
    ...
        filePathsForTransform:
          - dir1/somefile.json => output.json
```

**Example 3 - Wildcard examples**
The first item will replace all {filename}.tokenized.config target files and save the result in {filename}.config.
The second entry will replace tokens in all {filename}.tokenized.config target files and save the result in output\{filename}.config.
```yaml
    ...
        filePathsForTransform:
          - *.tokenized.config => *.config
          - **\*.tokenized.config => output\*.config
```
