# Pipeline

Generate `.github/workflows/deploy-azure.yml` from `templates/workflows/deploy-azure.yml`. Follow
the repository's own GitHub Actions rules if it has them; the template already applies the BC Gov
hardening pattern: deny-all `permissions: {}` with per-job step-ups, `id-token: write` only on jobs
that log in to Azure, `packages: write` only on the image job, first-party actions on a major tag,
third-party actions on a commit SHA, a pinned runner, `set -euo pipefail`, no stored credential.

## Tokens

| Token | Fill with |
| --- | --- |
| `@@WORKFLOW_NAME@@` | for example `Deploy to Azure` |
| `@@ENV_NAME@@` | the environment name from the interview (prefixes resource names and the resource group `rg-<name>`) |
| `@@AZURE_LOCATION@@` | `canadacentral` or `canadaeast` |
| `@@GH_ENVIRONMENT@@` | the GitHub environment name |
| `@@SRE_AGENT_MODE@@` | `none`, `attach` or `create` |
| `@@DATABASE_ENABLED@@` | `true` or `false` |
| `@@BICEP_VERSION@@` | the version the templates compile with |
| `@@TRIGGER@@` | see below |
| `@@FOUNDATION_OUTPUTS@@`, `@@FOUNDATION_OUTPUT_LINES@@` | a job output and the line that sets it, for each infra value an image build needs (one per `dependsOnInfra` build-time item in the inventory). Delete both if none. |
| `@@IMAGE_BUILDS@@` | one `build <name> <dockerfile> [--build-arg ...]` line per service in the plan, using `$DOMAIN` or another foundation output where a build needs it |
| `@@SMOKE_STEPS@@` | one `curl "${retry[@]}" ...` per check from the inventory: health path, identity provider issuer |

## Shape decisions

- **Tier.** Sandbox: any trigger the user picks. Production: the GitHub environment must have required
  reviewers, the trigger must be limited to a protected branch (never an unreviewed manual run), and
  a job that reaches a private data service needs a self-hosted runner inside the network (R32). The
  hosted-runner template does not cover that; see `tiers.md`.
- **Two passes.** Keep foundation, images, apps only if a build-time value depends on infrastructure
  (`buildTime[].dependsOnInfra` in the inventory). Otherwise build images first and deploy once;
  delete the foundation job and its outputs.
- **Trigger.** Start with `workflow_dispatch`. To chain on a build workflow later, use `workflow_run`
  with `workflows: [<build>]`, `types: [completed]`, and gate each job on
  `github.event.workflow_run.conclusion == 'success'`; check out `github.event.workflow_run.head_sha`,
  and treat that SHA as untrusted input (pass through `env:`). For a push trigger add a `paths:` filter.
- **Environment.** Jobs that log in use `environment: <name>`, so the OIDC subject is
  `repo:<owner>/<repo>:environment:<name>` and any required reviewers apply.
- **Agent job.** Keep it only for `attach`. For `create`, the Bicep creates the agent with the
  resource group already in `managedResources`.
- **Image tags.** The commit SHA, never `latest` or a fixed tag: a changed tag makes a new revision,
  and the same tag with an unchanged template does not pull a new image.
- **Registry path.** Lowercase: `ghcr.io/${GITHUB_REPOSITORY,,}`. Add the
  `org.opencontainers.image.source` label so the package links to the repository.
- **No parallel deployments.** The `concurrency` group has `cancel-in-progress: false`.

## Before committing it

Lint with `actionlint` if available, and at least parse the YAML. Run each `jq` expression against a
sample. Check no `${{ }}` of untrusted input sits inside a `run:` block. Confirm the federated
credential's subject matches the environment name.
