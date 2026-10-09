# sdlc-azure-deploy-skill

An agent skill that takes a containerised repository from "ready to deploy" to a verified running
deployment on Azure Container Apps in a BC Gov landing zone, connected to an Azure SRE Agent, with a
GitHub Actions pipeline that repeats it. It works with both Claude Code and GitHub Copilot in VS Code.

The agent scans the repo, plans the resources and code changes, has the plan checked and approved by
a human, applies the changes on a branch, walks the user through the one-time Azure and GitHub
bootstrap, generates a hardened OIDC deploy workflow, then deploys and verifies. The rules and phases
are in [skills/sdlc-azure-deploy/SKILL.md](skills/sdlc-azure-deploy/SKILL.md).

## Install

The skill is the directory `skills/sdlc-azure-deploy/`. Both runtimes read the same `SKILL.md`.

- **Claude Code:** copy or symlink it to `.claude/skills/sdlc-azure-deploy/` in the target repository
  (or `~/.claude/skills/` for every project). This repository also has a plugin manifest in
  `.claude-plugin/` for plugin-style installation.
- **GitHub Copilot in VS Code:** the same directory works under `.github/skills/` or `.claude/skills/`
  in the target repository.

The target repository's agent needs `az`, `gh`, `git`, `jq`, `docker`, `openssl` and the Bicep CLI.
Run `skills/sdlc-azure-deploy/scripts/preflight.sh` to check.

## Layout

| Path | What |
| --- | --- |
| `skills/sdlc-azure-deploy/SKILL.md` | The orchestrator: scope, rules, state, phases and gates |
| `.../references/` | Per-phase detail: scan, resource selection, BC Gov profile, bootstrap, pipeline, SRE agent, verification, lessons; `subagents/` holds the scanner and verifier prompts |
| `.../schemas/` | Inventory and state file schemas |
| `.../templates/bicep/` | Compiling Bicep: monitoring, environment, app, Postgres, alerts, agent access, SRE agent |
| `.../templates/workflows/` | The deploy workflow, with `@@TOKEN@@` placeholders |
| `.../templates/bootstrap/` | The bootstrap script and its inputs |
| `.../scripts/preflight.sh` | Read-only environment checks |
| `examples/digital-marketplace-next/` | The golden case: the working deployment this was extracted from, and the inventory a scan of it must produce |
| `check.sh` | Checks that need no Azure access |

## Status

Version 0.1: structure, rules, templates and the read-only and dry-run tooling. Nothing here has been
run end to end by an agent on a second repository.

Verified: the Bicep templates compile; the bootstrap script's dry run; the preflight script against a
real subscription; the golden inventory against its schema.

Not verified, and called out where it matters:

- **Creating an SRE agent through Bicep** (`sre-agent.bicep`) has never been deployed. See spike S1 in
  `references/sre-agent.md`.
- **Updating an agent from the pipeline's own identity**, and whether the agent can then see the
  application (S2, S3).
- **Landing-zone conflicts.** The golden example departs from several `bcgov-azure` rules (a direct
  Contributor assignment, public Postgres, secrets outside Key Vault, no Application Gateway). See
  `references/landing-zone-bcgov.md`.
- **Only Node and PostgreSQL are proven.** The scanner and templates are written to be general; other
  stacks need a run to find out.

## Not built yet

A deterministic scanner script (the scan is done by the agent for now), a plan verifier script, an
evaluation harness over several sample repositories, the Key Vault and private-network designs, and
support for any compute but Container Apps.

## Checks

```bash
./check.sh /path/to/digital-marketplace-next
```
