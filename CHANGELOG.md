# Changelog

All notable changes to this repository should be documented in this file.

## [1.2.0] - 2026-03-30

### Added
- Support for variable-file paths that include `{applicationID}` and `{instance}` placeholders in `common-infrastructure-deploy.yaml` (resolved at compile time when the new parameters are provided).
- New `repositoryRoot` parameter in `common-infrastructure-deploy.yaml` to support multi-repo checkouts where templates live under `$(Pipeline.Workspace)/s/self` rather than `$(Build.SourcesDirectory)/self`.
- New optional `templateName` field for deployments in `common-infrastructure-deploy.yaml` so validation/deploy steps can target a template file that is not named exactly the same as the deployment block.
- New `replaceTokensOnly` deployment type in `common-infrastructure-deploy.yaml` to allow running token replacement as a first-class deployment step (including an option to run the repo-local `scripts/pipeline/Replace-Tokens.ps1` under a custom working directory).
- Optional `retryCountOnTaskFailure` support for script steps in `templates/steps/powershell.yaml`.

### Changed
- `validate-deploy-arm-template.yaml` can now run token replacement from a configurable root directory (`tokenReplaceRootDirectory`) using relative paths, improving compatibility with non-standard checkout layouts.
- `validate-deploy-arm-template.yaml` adds a small retry for real deployments (deploy=true, whatIf=false) to reduce transient failures.
- `Template-Deployment.ps1` no longer creates resource groups during validation/what-if. If a resource group does not exist, it now skips RG-scoped validation/what-if rather than mutating the subscription.

### Backwards compatibility
- This is backwards compatible because:
  - All new inputs are **optional** (e.g. `applicationID`, `instance`, `repositoryRoot`, `tokenReplaceRootDirectory`, `templateName`, `retryCountOnTaskFailure`).
  - Existing pipelines keep the same default behaviour and paths (defaults still point at `$(Build.SourcesDirectory)/self`).
  - The change to RG handling only affects non-deploy operations (validate/what-if) and prevents unexpected side effects; actual deployments still create missing RGs when `deploy=true`.

## [1.1.7] - 2026-03-XX

### Added
- Previous release baseline (see git history/tags for details).

