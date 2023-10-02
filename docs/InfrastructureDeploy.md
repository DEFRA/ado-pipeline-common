[[_TOC_]]

# Route to live deployment using ARM/Bicep Template

## Introduction
Extend the `common-infrastructure-deploy.yaml` pipeline-template to create your route-to-live deployment strategy. This allows to set the list of environments that compose the route-to-live progression and sets the branching strategy. If you need scripts-only deployed use the [ScriptsOnlyDeploy.md](ScriptsOnlyDeploy.md) pipeline-template instead.

## Usage
Following pipeline code snippet is an example of how to call `common-infrastructure-deploy.yaml` template and implement deployment strategy:

```yaml
# Example deployment strategy:
# Deployment progression in environments as following: DEV -> SND -> TST -> PRE -> PRD
# Deployment using feature-branches, a single integration-branch and a single release branch:
#   - Deployment from a feature-branch allowed only in DEV with use of toggle/flag deployFromFeature to control deployment
#   - Deployment from an integration-branch (e.g. integration) allowed in DEV, SND, TST
#   - Deployment from an release-branch (e.g. main) allowed in DEV, SND, TST, PRE and PRD

parameters:
  - name: deployToDevelopmentEnvironment
    displayName: "Deploy from Feature Branch"
    type: boolean
    default: false

resources:
  repositories:
    - repository: PipelineCommon
      name: DEFRA/ado-pipeline-common
      type: git
      ref: refs/tags/Release-v1-latest

extends:
  template: /templates/pipelines/common-infrastructure-deploy.yaml@PipelineCommon
  parameters:
    deployFromFeature: ${{ parameters.deployToDevelopmentEnvironment }}
    privateAgentName: <private agent pool name> (optional)
    agentImage: <Microsoft-hosted agent image name> (optional, default 'windows-latest')
    filePathsForTransform: (optional)
      - <file-path>
    environments: (required)
     - name: 'dev' (required)
       developmentEnvironment: True (required - it must be set in the 1st environment in environments property)
       useDevelopmentEnvironmentForValidationOnly: True (optional - Only required if you have a single Production environment in your pipeline, so the Validation stage can validate the deployment against a development environment and not Production)
       azureRegions:
        primary: NorthEurope
       serviceConnection : <name of the service connection> (required)
       privateAgentName: <private agent pool name> (optional)
       agentImage: <Microsoft-hosted agent image name> (optional)
       KeyVaultList: (optional)
          - Name: <name of Key Vault to load secrets from> (required)
            SecretsFilter: <comma delimited list of secrets> (optional)
            serviceConnection: <service connection> (optional)
     - name: 'snd' (required)
       enableTemplateValidationBeforeDeployment: True (optional, default false)
       azureRegions:
        isSecondaryRegionDeploymentActive: false (optional, default true)
        deployPrimaryAndSecondaryInParallel: false (optional, default true)
        primary: NorthEurope
       serviceConnection : <name of the service connection> (required)
       userCustomVariables: <object of dynamically created key value pair variables and/or variable files reference> (optional)
       deploymentBranches:
        - 'refs/heads/integration'
        - 'refs/heads/main'
       outputTemplateChange: Skip|RunWithoutPause|RunWithPause (optional - The `outputTemplateChange` is an optional feature that takes Skip, RunWithoutPause and RunWithPause and if not set by default it will use RunWithoutPause.  This feature will not run on the environment being used as the developmentEnvironment (developmentEnvironment = True))
     - name: 'tst' (required)
       azureRegions:
        primary: NorthEurope
        secondary:
        - WestEurope
       serviceConnection: <name of the service connection> (required)
       userCustomVariables: <object of dynamically created key value pair variables and/or variable files reference> (optional)
       deploymentBranches:
        - 'refs/pull/*/merge'
        - 'refs/heads/integration'
        - 'refs/heads/main'
       outputTemplateChange: Skip (optional)
     - name: 'pre' (required)
       enableTemplateValidationBeforeDeployment: True
       azureRegions:
        isSecondaryRegionDeploymentActive: true
        deployPrimaryAndSecondaryInParallel: false
        primary: NorthEurope
        secondary:
        - WestEurope
        - UKSouth
       serviceConnection: <name of the service connection> (required)
       userCustomVariables: <object of dynamically created key value pair variables and/or variable files reference> (optional)
       deploymentBranches:
        - 'refs/heads/main'
       outputTemplateChange: RunWithPause (optional)
     - name: 'prd' (required)
       enableTemplateValidationBeforeDeployment: True
       azureRegions:
        isSecondaryRegionDeploymentActive: true
        deployPrimaryAndSecondaryInParallel: true
        primary: NorthEurope
        secondary:
        - WestEurope
        - UKSouth
       serviceConnection: <name of the service connection> (required)
       userCustomVariables: <object of dynamically created key value pair variables and/or variable files reference> (optional)
       deploymentBranches:
        - 'refs/heads/main'
       outputTemplateChange: RunWithPause (optional)
    variableFiles: (optional)
     - /vars/{environment}.yaml@self
    regionalVariableFiles: (optional)
     - /vars/regional/{environment}-{region}.yaml@self
    additionalRepositories: (optional)
     - <additional-repo1-name>
     - <additional-repo2-name>
    groupedDeployments: (required)
      - name: <group-name> (required - Hyphens are not supported, please use underscores)
        dependsOngroupedDeployments: (optional - All jobs will run in parallel if no dependency is defined. Else, the dependsOngroupedDeployments will be respected for job runs.)
          - <group-name1> (optional)
          - <group-name2> (optional, can be no groups or multiple groups)
        deployments:
          - name: <deployment-name> (required, when type is arm/bicep template provide the name of the template without extension json/bicep otherwise plain text for script step display name)
            path: <template-or-script-path> (required, folder path where the template/script resides)
            type: <deployment-type> (optional, accepted values are arm, bicep or script and default value is arm)
            isDeployToSecondaryRegions: false (optional and default is True. Set it to false to skip the deployment for this template in the secondary regions)
            parameterFilePath: <template-parameter-file-path> (optional, can be used when template file and parameter file are in different folder)
            serviceConnectionVariableName: <name-of-the-service-connection> (optional)
            preDeployServiceConnectionVariableName: <name-of-the-service-connection> (optional)
            postDeployServiceConnectionVariableName: <name-of-the-service-connection> (optional)
            acrServiceConnection: <name-of-the-service-connection> (optional, Use it when bicep template references module from an Azure container registry.)
            scope: <resource-deployment-scope> (required)
            resourceGroupName: <resource-group-name> (required)
            preDeployScriptsList: (optional)
              - displayName: <display-name> (optional)
                Type: <type> (Optional, Avalibale values: AzurePowerShell, PowerShell, AzureCLI. Default: AzurePowerShell)
                azurePowershellUseCore: (optional, Applies when using `Type`: AzurePowerShell, PowerShell. Default is false)
                AzureCLIScriptType: (optional, Applies when using `Type`: AzureCLI. Avalible values: ps, pscore, batch, bash. Default is ps)
                useSystemAccessToken: (optional, default false)
                scriptPath: <script-path> (required)
                scriptRepo: <script-repo> (required, if scriptPath does not refer @PipelineCommon)
                ScriptArguments: <script-arguments> (optional)
                serviceConnectionVariableName: <name-of-the-service-connection> (optional)
            postDeployScriptsList: (optional)
              - displayName: <display-name> (optional)
                Type: <type> (Optional, Avalibale values: AzurePowerShell, PowerShell, AzureCLI. Default: AzurePowerShell)
                azurePowershellUseCore: (optional, Applies when using `Type`: AzurePowerShell, PowerShell. Default is false)
                AzureCLIScriptType: (optional, Applies when using `Type`: AzureCLI. Avalible values: ps, pscore, batch, bash. Default is ps)
                useSystemAccessToken: (optional, default false)
                scriptPath: <script-path> (required)
                scriptRepo: <script-repo> (required, if scriptPath does not refer @PipelineCommon)
                ScriptArguments: <script-arguments> (optional)
                serviceConnectionVariableName: <name-of-the-service-connection> (optional)
            scriptType: <type-of-the-script> (optional, Use it when deployment `type` is script. Default value is AzurePowershell and accepted values as AzurePowershell, PowerShell or AzureCLI.)
            scriptRepo: <name-of-the-script-repo> (optional, Use it when deployment `type` is script and scripts are defined in a different repository.)
            inlineScript: <inline-script> (optional, Use it when deployment `type` is script.)
            azurePowershellUseCore: <script-arguments> (optional, Use it when deployment `type` is script and Applies when using `ScriptType` is AzurePowerShell or PowerShell. Default is false)
            scriptArguments: <script-arguments> (optional, Use it when deployment `type` is script)
        preDeployManualTasks: (optional)
          - displayName: <display-name> (required)
            timeoutInMinutes: <timeout-in-minutes> (required)
            instructions: <instructions> (required)
```

  | :warning: The shared pipeline repository is referred to a as `@PipelineCommon` also internally and therefore is a reserved repository name. If you need an additional repository resource use a different name (e.g. `@ProjectRepo`) as the repository names within the resources block need to be unique when the pipeline template is evaluated. The rational here is that the definition of the exact used resource sits in the consumer yaml file allowing for versioning via the `ref` (branch or tag). |
  |:----------|

  | :warning: You should always use latest tagged version (e.g. `refs/tags/Release-v1-latest`) in `ref` for `DEFRA/ado-pipeline-common` repository. Main branch should not be used as this may change at any time and may contain breaking changes. The `DEFRA/ado-pipeline-common` repository uses Semantic Versioning for version tagging. Breaking changes will result in a new release version while non-breaking changes will have the minor or patch version increased and can be referred to via the latest release tag. |
  |:----------|

## Pipeline parameters

### privateAgentName/agentImage

`privateAgentName` and `agentImage` both define the agents used to run the pipeline. `privateAgentName` is used to set a self-hosted private agent pool, while `agentImage` is used to run the pipeline on Microsoft-hosted agents ([see full list of images](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml#software)). By default the pipeline deploys using Microsoft-hosted *'windows-latest'* image. `privateAgentName` or `agentImage` can be set either at the pipeline level (global) or at environment level (environment overwrite). If both `privateAgentName` and `agentImage` are set then `privateAgentName` takes precedence.

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

`azureRegions` : Provide the list of azure regions using `primary` and `secondary` property for each environment. The following are supported regions values : **northeurope**, **westeurope**, **uksouth** and **ukwest**

- `isSecondaryRegionDeploymentActive` Optional - default is true. Set it to false to skip the deployment for that environment in the secondary regions. This property takes effect only when `secondary` is supplied.
- `deployPrimaryAndSecondaryInParallel` Optional and default is true. When true it runs the primary and secondary regions deployment jobs parallelly. Set it to false to run the primary and secondary regions deployment jobs sequencially.
- `primary` is mandatory and it should contain only single region which is the primary region for the deployment.
- `secondary` contains list of regions and more than one regions can be provided for deployment in the multiple secondary regions.

```yaml
  azureRegions:
    isSecondaryRegionDeploymentActive: true (Optional, default is true. This property takes effect only when secondary is supplied )
    deployPrimaryAndSecondaryInParallel: true (Optional, default is true)
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
     enableTemplateValidationBeforeDeployment: True
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
     serviceConnection : <service-connection>
     dependsOn: 'dev'
  - name: 'tst_green'
     enableTemplateValidationBeforeDeployment: True
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
     serviceConnection : <service-connection>
     dependsOn: 'dev'
     outputTemplateChange: RunWithPause
  - name: 'pre_blue'
     enableTemplateValidationBeforeDeployment: True
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
     serviceConnection : <service-connection>
     dependsOnAny: True
     dependsOn: [tst_blue,tst_green]
  - name: 'pre_green'
     enableTemplateValidationBeforeDeployment: True
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
     serviceConnection : <service-connection>
     dependsOnAny: True
     dependsOn: [tst_blue,tst_green]
     outputTemplateChange: RunWithPause
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

#### enableTemplateValidationBeforeDeployment

The `enableTemplateValidationBeforeDeployment` Optional - default is false. `enableTemplateValidationBeforeDeployment` is an optional feature that will allow to validate (dry run) templates before actual deployment. This feature will not run on the environment being used as the developmentEnvironment (developmentEnvironment = True)

#### keyVaultList

`keyVaultList` an optional list of Azure Key Vaults that is used to pull secrets from. When non-empty the `Name` field is mandatory. The items on the list can be configured individually with the following parameters:

- `Name` (required) Name of the Key Vault. Can be an ADO variable used as reference (see example below).
- `SecretsFilter` (optional, defaults to '*') Comma-separated list of secrets to load from the given Key Vault. When missing this loads all secrets from a given Key Vault.
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

#### outputTemplateChange

The `outputTemplateChange` (what-if) runs by default. The `outputTemplateChange` is an optional feature that takes Skip, RunWithoutPause and RunWithPause and if not set by default it will use RunWithoutPause.  This feature will not run on the environment being used as the developmentEnvironment (developmentEnvironment = True) unless you include the property [forceWhatIf](#forcewhatif)

Allowed values are:

* `Skip` - Setting Skip will prevent the what-if operation to run.
* `RunWithoutPause` - Setting RunWithoutPause will only run the what-if operation.  This is also used as the deafult option if outputTemplateChange is not set
* `RunWithPause` - Setting RunWithPause will pause the pipeline run after the what-if operation has completed. This will allow you to review any potential changes prior to deployment.

The syntax for defining multiple environment and their dependencies is:

```yaml
environments:
   - name: 'dev'
     azureRegions:
       primary: NorthEurope
     developmentEnvironment: True
     serviceConnection : <service-connection>
   - name: 'tst'
     enableTemplateValidationBeforeDeployment: True
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
       secondary:
       - WestEurope
       - UKSouth
     serviceConnection : <service-connection>
     dependsOn: 'dev'
     outputTemplateChange: RunWithPause
```

#### forceWhatIf

The `forceWhatIf` parameter allows you to override the default functionality that dev environments do not run what-if. The default option is not set which should should allow default behaviour as explained above to happen.

Allowed values are:

* `True`
* `False`

You **MUST** use `forceWhatIf` in conjunction with  [outputTemplateChange](#outputtemplatechange)

```yaml
environments:
   - name: 'dev'
     azureRegions:
       primary: NorthEurope
     developmentEnvironment: True
     serviceConnection : <service-connection>
     forceWhatIf: True
   - name: 'tst'
     enableTemplateValidationBeforeDeployment: True
     azureRegions:
       deployPrimaryAndSecondaryInParallel: true
       primary: NorthEurope
       secondary:
       - WestEurope
       - UKSouth
     serviceConnection : <service-connection>
     dependsOn: 'dev'
     outputTemplateChange: RunWithPause
```

#### tokenReplaceEscapeConfig

`tokenReplaceEscapeConfig` parameter allows you to override the default configuration of the [token replace step](https://marketplace.visualstudio.com/items?itemName=qetza.replacetokens).
Default behaviour is for escaping strings to be inferred automatically e.g. when passing in a json string quotes will be escaped with \\".
Sometimes this behaviour is not not desired so the value none can be set to prevent escaping.

Allowed Values are:

* none
* auto
* json
* xml
* custom (not implemented into pipelines)

##### With Auto selected

```json
{
  "appGatewayListeners": {
    "value": [
      {\"name\": \"rwd-listener\",\"protocol\": \"https\", \"hostname\": \"epl-dev1.azure.defra.cloud\"}]}
    }
  }
}
```

##### With none selected

```json
{
  "appGatewayListeners": {
    "value": [
      {
        "name": "rwd-listener",
        "protocol": "https",
        "hostname": "epl-dev1.azure.defra.cloud"
      }
    ]
  }
}
```

```yaml
extends:
  template: /pipeline/infra-template.yaml
  parameters:
    deployments:
      - name: applicationGateway
        path: applicationGateway
        type: "arm"
        resourceGroupName: "$(appGwResourceGroupName)"
        scope: "Resource Group"
    deployFromFeature: ${{ parameters.deployFromFeature }}
    tokenReplaceEscapeConfig: none
```

#### serviceConnection

The `serviceConnection` property defines the default ADO service connection used for the given environment.  This is mandatory when you define environments.

#### useDevelopmentEnvironmentForValidationOnly

The `useDevelopmentEnvironmentForValidationOnly` property must be in the first environment defined in the 'environments' property if you have a single Production environment in your pipeline, so the Validation stage can validate the deployment against a development environment and not Production.

#### userCustomVariables

The `userCustomVariables` are defined by consumers to pass dynamic parameters of type string as key value pair or variable file on pipeline run (see examples below).

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
        enableTemplateValidationBeforeDeployment: true
        serviceConnection: AZD-CDO-TST1
        userCustomVariables: ${{ parameters.customVariables }}
   ```
   **Example 2: defined as inline in environment object.**

   ```yaml
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

### preDeployManualTasks
`preDeployManualTasks` list of manual tasks prompted during a pipeline-run and before the execution in a `groupedDeployments` of the  `preDeployScriptsList` and `deployments`.

  ```yaml
  preDeployManualTasks:
    - displayName: Task for Group1
      timeoutInMinutes: 10
      instructions: Please validate Task for Group1 and resume
    - displayName: Task for Group1
      timeoutInMinutes: 10
      instructions: Please validate Task for Group1 and resume
  ```

  ![manual-validation-1](assets/images/manual-validation-1.png =750x)

  ![manual-validation-2](assets/images/manual-validation-2.png =350x) ![manual-validation-3](assets/images/manual-validation-3.png =350x)

### ARM/bicep-template parameters

#### isDeployToSecondaryRegions

`isDeployToSecondaryRegions` (optional, default value `true`) Flag to control whether to deploy templates in the secondary regions. Setting to `false` will skip the secondary regions.

Example

```yaml
extends:
  template: /templates/defra-common-arm-deploy.yaml@trdPipelineCommon
  parameters:
    deployments:
      - path: webapps/Defra.Trade.DataMapping.API
        name: webapp-data-mapping
        isDeployToSecondaryRegions: false
        type: bicep
```

#### type

`type` (optional, default value `arm` ) type of the template to deploy. Supported values: *arm* or *bicep*.

Example

```yaml
extends:
  template: /templates/pipelines/common-infrastructure-deploy.yaml@PipelineCommon
  parameters:
    deployments:
      - path: webapps/Defra.Trade.DataMapping.API
        name: webapp-data-mapping
        type: bicep
```

#### acrServiceConnection

`acrServiceConnection` (optional, default value `''` ) Azure Resource Manager Service connection to connect to Azure container registry. Use it when bicep template references module from an Azure container registry.

Example

```yaml
extends:
  template: /templates/pipelines/common-infrastructure-deploy.yaml@PipelineCommon
  parameters:
    deployments:
      - path: webapps/Defra.Trade.DataMapping.API
        name: webapp-data-mapping
        type: bicep
        scope: "Resource Group"
        acrServiceConnection: AZD-CDO-XXX
```

#### preDeployScriptsList/postDeployScriptsList

`preDeployScriptsList` and `postDeployScriptsList` list of Powershell scripts that can be run before or after the ARM deployments. It can be run using `inlineScript` or `scriptPath`. Scripts can be run from the client repository, any third party repository or from the Common Pipeline in which the `scriptPath` takes a different form as shown below. `scriptRepo` is the alias of the repository where the scripts reside, and is required when not referring scripts from the Common Pipeline(PipelineCommon) or self(consuming repository). **`runCondition`** can be used has a boolean custom flag to run a specific script or not.

* Script form consumer repository (self)
  ```yaml
  preDeployScriptsList:
    - displayName: Hello World!
      scriptPath: 'powershell\test.ps1'
  ```
* Script form third party repository
  ```yaml
  resources:
    repositories:
    - repository: thirdPartyRepo
      name: DEFRA-TRD/Defra.TRD.Pipeline.Common
      type: git
      ref: main
  ```
  ---
  ```yaml
  preDeployScriptsList:
    - displayName: Run script
      runCondition: $(variables.enableScript)
      scriptPath: 'powershell\runScript.ps1'
      scriptRepo: 'thirdPartyRepo'
  ```

* Inline script
  ```yaml
  preDeployScriptsList:
    - displayName: Hello World!
      type: PowerShell
      inlineScript: PrivateModuleFunctionName -Arg01 <value-01> -Arg02 <value-02>
  ```

* Multiline script
  ```yaml
  preDeployScriptsList:
    - displayName: Hello World!
      type: PowerShell
      inlineScript: |
        Write-Host "Multi line script"
        PrivateModuleFunctionName -Arg01 <value-01> -Arg02 <value-02>
  ```
##### commonModulesToLoad

`commonModulesToLoad` Use it to install Powershell modules hosted in private common feed [defra-devops-common](https://dev.azure.com/defragovuk/DEFRA-DEVOPS-COMMON/_artifacts/feed/defra-devops-common). Use this option to call functions from the private modules inside the script. Functions from the private module can be executed using `inlineScript` or `scriptPath`. Supported script type = `Powershell`, `AzurePowershell` and `AzureCLI`. For `AzureCLI` only `AzureCLIScriptType = ps or pscore` is supported.

**Prerequisite:** Project should host their Powershell modules as a Nuget package to this private common feed [defra-devops-common](https://dev.azure.com/defragovuk/DEFRA-DEVOPS-COMMON/_artifacts/feed/defra-devops-common).

* Executing script using `inlineScript` which can directly execute function from the private module
  ```yaml
  preDeployScriptsList:
    - displayName: Function call(With parameters) from the Private Module
      inlineScript: Get-FirstHellowithParameter -Arg01 <value-01> -Arg02 <value-02>
      commonModulesToLoad:
        - name: '<ModuleName1>'
          version: '1.0.0' (Optional, Default version = latest)
        - name: '<ModuleName2>'
          version: '1.0.2' (Optional, Default version = latest)

  postDeployScriptsList:
    - displayName: Function call(With parameters) from the Private Module
      type: PowerShell
      inlineScript: |
        Write-Host "Multi line script"
        Get-FirstHellowithParameter -Arg01 <value-01> -Arg02 <value-02>
      commonModulesToLoad:
        - name: '<ModuleName1>'
          version: '1.0.0' (Optional, Default version = latest)
        - name: '<ModuleName2>'
          version: '1.0.2' (Optional, Default version = latest)
  ```

* Executing script using `scriptPath` which can run function from the private module
  ```yaml
  postDeployScriptsList:
    - displayName: AzurePowerShell = (pwsh = true)Function call from the Private Module Inside consumer script
      type: AzurePowerShell
      scriptPath: package-feed-consumer/scripts/runScript.ps1  (Inside this script module's function can be called)
      scriptArguments: >
        -DummyParameter 'CallingModuleFunctionInsideConsumerScript'
      commonModulesToLoad:
        - name: '<ModuleName1>'
        - name: '<ModuleName2>'
      azurePowershellUseCore: true
    ```

##### failOnStandardError

`failOnStandardError` (optional, default value `false`) Flag to control whether the ADO task running the script should stop the pipeline while encountering a Standard Error.

##### filePathsForTransform

`filePathsForTransform` is a list of files to parse and replace any occurrence of ADO variables with their values. ADO variables need to be wrapped in `#{{ }}`.

**Example 1 - Replace token and update file.**
`somefile.config` is a template config file that will inject the values from ADO variables. The updated file is then feed into the script as na config.

```yaml
  filePathsForTransform: |
    relative-path/somefile.config
```

**Example 2 - File generation based on templates.**
```yaml
    ...
  filePathsForTransform:
    - dir1/somefile.json => output.json
```

**Example 3 - Wildcard examples**
```yaml
    ...
  filePathsForTransform:
    - *.tokenized.config => *.config
    - **\*.tokenized.config => output\*.config
```
* The first item will replace all `{filename}.tokenized.config` target files and save the result in `{filename}.config`.
* The second entry will replace tokens in all `{filename}.tokenized.config` target files and save the result in `output\{filename}.config`.

##### serviceConnectionVariableName

`serviceConnectionVariableName` (optional) name of the variable where the service-connection is set and to be used for current script of the scriptList (local overwrite). If not set in `postDeployScriptsList` or `postDeployScriptsList` it defaults to `preDeployServiceConnectionVariableName` or `postDeployServiceConnectionVariableName` respectively.

```yaml
preDeployScriptsList:
  - displayName: Hello World!
    scriptPath: 'powershell\test.ps1'
    serviceConnectionVariableName: serviceConnection1
  - displayName: Run script
    scriptPath: 'powershell\runScript.ps1'
    scriptRepo: 'thirdPartyRepo'
```

#### preDeployServiceConnectionVariableName

`preDeployServiceConnectionVariableName` name of the variable where the service-connection is set and to be used for pre deployment scripts. If not set template `serviceConnectionVariableName` is used.

#### postDeployServiceConnectionVariableName

`postDeployServiceConnectionVariableName` name of the variable where the service-connection is set and to be used for pre deployment scripts. If not set template `serviceConnectionVariableName` is used.

#### serviceConnectionVariableName

`serviceConnectionVariableName` name of the variable where the service-connection is set and to be used for the ARM Template deployment. If not set environment `serviceConnection` is used.

#### useSystemAccessToken

Default is `false`. Setting this variable to 'true' allows use of '$env:SYSTEM_ACCESSTOKEN' variable inside script.

## Pipeline Parameters as variables
Pipeline parameters can be used as variables and get injected into ARM templates along with variables defined in the variable files. Those parameters needs to be passed as global variables in the project yaml pipeline, see below example.
```yaml
parameters:
  - name: variable1
    type: string
    default: <default-value>
  - name: variable2
    type: string
    default: <default-value>

variables:
  - name: variable1
    value: ${{ parameters.variable1 }}
  - name: variable2
    value: ${{ parameters.variable2 }}

resources:
  repositories:
    - repository: PipelineCommon
      name: DEFRA-DEVOPS-COMMON/Defra.Pipeline.Common
      type: git
      ref: refs/tags/Release-v6-latest

extends:
  template: /templates/pipelines/common-infrastructure-deploy.yaml@PipelineCommon
...
```
