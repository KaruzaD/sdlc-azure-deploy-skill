# Verification

Two uses: checking the plan before approval (phase 3) and checking the deployment (phase 7).

## The plan, before approval

### Mechanical checks (you run these)

1. Every `file:line` in the inventory and plan exists and the line says what is claimed.
2. The inventory validates against `schemas/inventory.schema.json`.
3. Every resource in the plan traces to an inventory finding; every finding that needs a resource
   appears in the plan.
4. `bicep build infra/azure/main.bicep` succeeds with no new warnings; `bicep build-params` works
   with sample values.
5. Each image in the plan builds locally with the build arguments the pipeline will pass.
6. The repository's own tests and build pass with the proposed code changes applied on the branch.
7. `az deployment sub what-if` (or `validate`) runs against the subscription. A pass does not mean the
   policy will accept it; see the canary.
8. The pipeline would run with the roles and scopes the plan lists, and none more.
9. The tier is recorded. The plan has a rule compliance table covering every class A and class B
   rule that applies. In sandbox every departure is in the deviation register with a
   `productionNeeds` entry and no class A rule is listed as a departure. In production there is no
   departure at all, and every missing template is on the gap list.

### Independent verifier

Start a fresh, read-only subagent with `subagents/verifier.md`, the inventory, the plan and read
access to the repository. It was not part of the scan or plan, and its job is to find where they are
wrong. Do not give it your reasoning, only the artefacts. When there is no subagent tool, finish the
mechanical checks, then re-read the plan as the verifier would, from the artefacts alone, and say that
you could not run an independent one.

Triage its findings with the user: fix, accept with a reason, or mark as unknown. Do not argue a
finding away. Show the user both the plan and the findings at the gate.

### Approval record

After a human approves, write to the state file: who, when and the SHA-256 of `plan.md`. If the plan
changes afterwards, approval is void. Ask again.

## The deployment, after it runs

Report each check with its evidence (the command and what it returned), not "it worked".

| Check | How |
| --- | --- |
| The workflow succeeded | `gh run view`; every job green, not skipped by mistake |
| The new revision is running and healthy | `az containerapp revision list --all` for each app; the latest is active, `Healthy`, and created after the run started |
| The new image is the one deployed | the revision's image tag equals the commit SHA |
| The health endpoint answers | `curl` the public URL with retries; expect 200 |
| The identity provider, if any | its discovery document's `issuer` equals the address the app verifies |
| A real sign-in, if there is one | drive it with a script or browser; confirm the app sees the user |
| Mail, if it sends | trigger one and read it in the catcher |
| Database | a write succeeds; the migration init container completed |
| Persistence | write, restart a revision, read |
| Telemetry reaches the workspace | `az monitor log-analytics query` against `AppRequests`, `AppExceptions`, and the Container Apps log tables; role name is the service name |
| Alerts and the availability test exist and are enabled | `az monitor metrics alert list` |
| The SRE agent is attached | `provisioningState` is `Succeeded`, the resource group is in `managedResources`, mode unchanged, roles present |
| The agent can answer about it | spike S3 in `sre-agent.md`; say if not done |

Report anything you could not check and why.

## What not to do

- Do not use `az containerapp exec` for a command: it is interactive only. Verify through the public
  interface or the logs.
- Do not use `az monitor app-insights query`: it stops on an extension prompt.
- Do not call a check passed from a green workflow alone.
