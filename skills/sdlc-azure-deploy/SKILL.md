---
name: sdlc-azure-deploy
description: 'Takes a containerised repository from "ready to deploy" to a verified deployment on Azure Container Apps in a BC Gov landing zone, wired to an Azure SRE Agent. Scans the repo, plans resources and code changes, has the plan verified and approved by a human, applies the changes on a branch, guides the one-time Azure and GitHub bootstrap, generates a hardened OIDC GitHub Actions deploy workflow, then deploys and checks it. Use when asked to deploy a project to Azure, set up an Azure dev or test environment, connect or create an SRE agent for an app, or add an Azure deploy pipeline. Not for other clouds, OpenShift, or production.'
---

# Deploy a repository to Azure Container Apps with an SRE agent

You are taking a repository from "ready to deploy" to a verified running deployment, with the SRE
agent attached, and a pipeline that repeats it. You work with a human who owns every decision that
changes shared systems. The sections below are the rules and the phases; the detail for each phase
is in `references/`.

## Scope

- In: Azure Container Apps, one dev or test environment, BC Gov landing zone profile, GitHub Actions,
  an SRE agent created or attached.
- Out: production, other clouds, App Service, Functions, Static Web Apps, OpenShift. Say so and stop
  if the user asks for one.
- Read `references/landing-zone-bcgov.md` before planning, and the `bcgov-azure` skill's
  `CONVENTIONS.md` if it is installed. Where they disagree with a template, the rules win and the
  template changes.

## Rules

These hold in every phase. Do not trade them for speed.

1. **Nothing mutating without consent.** Before any `az`, `gh` or `git push` command that creates,
   changes or deletes something, show the exact command and its scope, and wait for a yes. A yes
   to a named step covers the commands in it. Read-only commands need no consent.
2. **Secrets never pass through the conversation.** Do not ask for, print, log or store one. Generate
   it locally and pipe it to its destination (`openssl rand ... | gh secret set`). Do not use a
   question prompt for a password or key. If a step needs one the user holds, tell them to type it into the
   terminal themselves.
3. **No stored cloud credential.** Workflows sign in with OIDC. Never add a client secret or personal
   access token as a fallback when a federated credential fails; fix the subject claim.
4. **Humans approve.** The plan needs explicit human approval before any change. Code changes go on a
   branch and a pull request for review, never straight to the default branch. You do not approve,
   merge or edit governance documents (a constitution, an ADR's status) to grant your own exception:
   draft the proposal and leave the decision to the owner.
5. **Least privilege, in code.** Narrowest scope, narrowest role, a condition where one can limit a
   role-assignment right. Never Owner. Never grant yourself more than the plan lists.
6. **Synthetic data only.** Ask what data the environment will hold. If it could be real personal
   information, stop: that needs a privacy assessment, not this skill.
7. **Evidence over assertion.** Every claim in an inventory or plan cites a file and line, a command's
   output, or a document. Say "unknown" when you do not know.
8. **Preview APIs are re-checked.** The SRE agent API is a preview. Treat what the references say as
   a lead, confirm it against the tenant before relying on it, and record what you confirmed in the
   state file with the date.
9. **Preflight does not prove a design is allowed.** Landing-zone policy can deny at deployment time
   what validation accepted. Run the canary deployment (phase 4) early.
10. **Teardown only on request.** Never delete a resource group, identity or registry package unless
    the user names it and asks.

## State

Keep `.azure-deploy/state.json` in the target repository (schema: `schemas/state.schema.json`).
Update it at the end of every phase and commit it with the work. It holds decisions, approvals, IDs
and the date each preview-API fact was checked. It never holds a secret. On start, read it: if it
exists, resume from its `phase` and tell the user where you are.

## Phases

Tell the user which phase you are in. Each ends at a gate; do not cross it without the stated
approval.

### 0. Preflight

Run `scripts/preflight.sh`. It is read-only: tools, `az` and `gh` login, subscription, your roles
including those through groups, resource providers, visible policy, existing SRE agents, repository
visibility. Fix FAIL lines with the user. Treat WARN lines as questions to ask in phase 5.
Detail: `references/bootstrap.md`.

### 1. Scan

Delegate to a read-only subagent with `references/subagents/scanner.md` (a fresh context; use your
runtime's subagent tool, or follow it yourself in a clean pass if there is none). It writes
`.azure-deploy/inventory.json` (schema: `schemas/inventory.schema.json`). Checklist:
`references/scan-checklist.md`. Also look for the repository's own governance (a constitution,
decision records, CODEOWNERS) and any rule about deploy targets; that decides whether a recorded
exception is needed.

### 2. Plan

Turn the inventory into `.azure-deploy/plan.md` using `references/resource-selection.md`:

- the resources, each tied to the inventory finding that requires it;
- every code change with its reasoning and evidence;
- the cost estimate and the ongoing cost of leaving it running;
- the governance items (an exception to draft, who must approve it);
- the risks, the unknowns, and what you will confirm with a canary deployment.

### 3. Verify, then approve (gate)

Run the checks in `references/verification.md`: mechanical checks first, then the independent
verifier (`references/subagents/verifier.md`, fresh context, read-only, told to refute the plan).
Fix what it finds and repeat. Then show the user the plan, the verifier's findings and what you
changed because of them. Do not continue until a human approves; record who, when and a hash of the
plan in the state file.

### 4. Apply

On a new branch: make the approved code changes, add `infra/azure/` from the templates (compile with
`bicep build`), run the repository's own tests and build. Then run the **canary**: a minimal
deployment (the foundation resources plus one small app) into the real subscription to surface
policy denials early, once the user agrees to the scope. Open a pull request. Detail:
`references/landing-zone-bcgov.md`, `references/lessons.md`.

### 5. Interview and bootstrap (gate)

Ask the user, one topic at a time, and record answers in the state file: subscription, location,
environment name, bootstrap resource group and identity names, GitHub repository and environment,
image registry, whether to create an SRE agent or attach to an existing one (and which), its run
mode, how the workflow should be triggered. Explain each choice and its consequence; do not
assume the previous project's answers.

Then generate `bootstrap.env` and `bootstrap.sh` from `templates/bootstrap/`, show the dry run
(`./bootstrap.sh --dry-run all`), and decide with the user who runs which step. If the user lacks
the rights for `roles`, write the request for whoever has them (exact roles, scopes, conditions and
why) and stop until they report back. Run the steps once the user agrees. Detail:
`references/bootstrap.md`.

### 6. Workflow

Ask when the workflow should run (manual now, or after the build workflow, on a push, on a tag), and
whether the environment needs reviewers. Generate `.github/workflows/deploy-azure.yml` from
`templates/workflows/deploy-azure.yml`, following `references/pipeline.md` and the repository's
`github-actions` skill if it has one. Commit it on the branch.

### 7. Deploy and verify

Run the workflow, watch it, and check the result with `references/verification.md`: the health
endpoint, the identity provider if there is one, telemetry reaching the workspace, and the SRE
agent attached. If a step fails, diagnose from the logs, fix the cause, and say what you changed.
Do not retry blindly. Write a short report with the evidence for each check.

### 8. Hand off

Write `infra/azure/README.md` (what exists, how to run and tear down, the bootstrap record), draft
any decision record the plan called for, list the open items and what costs money while it runs.
Set `phase` to `handed-off`.

## When something does not fit

If the repository needs something the scope excludes, or a rule in `landing-zone-bcgov.md` blocks the
design, say which, do not work around it, and ask. A request to the platform team is a finding, not
a failure.
