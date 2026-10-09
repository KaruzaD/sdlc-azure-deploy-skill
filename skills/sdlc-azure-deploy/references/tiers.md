# Tiers: sandbox and production

The tier is chosen first, before the scan, and it decides how every BC Gov rule is treated. Do not
infer it from the repository or its name, and do not change it part-way: a change is a new run from
phase 0 with the earlier approval void.

## The question

Ask it in phase 0, after preflight, in plain words:

> Is this environment for development and testing with synthetic data only, or is it production (or
> will it become production without being rebuilt)?

State the consequence before taking the answer:

- **Sandbox.** For development and testing, synthetic data only. Where the design departs from a BC
  Gov rule I record the departure, you approve it, and I attempt it. The landing zone's own policy
  still has the last word, and a departure it denies must be redesigned. A sandbox cannot be
  promoted as it is.
- **Production.** The BC Gov rules are binding. A departure blocks approval, and I will not deploy
  anything that departs. Today this path ends at an approved plan and a list of what is missing
  (see "Production path today").

If the user is unsure, take sandbox, say the environment must hold no real personal information and
cannot be promoted as it is, and ask them to confirm.

For production, also ask for and record, without judging them: the privacy impact assessment
reference (normally required before personal information is handled), the security assessment,
and the change process the deployment falls under. If the user has none, stop: the skill cannot
supply them.

For sandbox, confirm the data is synthetic. If it could be real, stop.

## Subscription guard

BC Gov subscriptions are named `<licence plate>-<env>` (observed: `dbc1c3-dev`). After the tier is
known, `scripts/preflight.sh --tier <tier>` compares it with the subscription's name. A sandbox run
against a subscription whose name ends `-prod` is a FAIL: do not continue. A production run against
one that does not is a WARN to resolve with the user. This is a naming heuristic, not proof.

## Rule classes

The rule numbers are those of the `bcgov-azure` skill's `CONVENTIONS.md`. Read it; this is how the
tiers treat them.

### Class A: no departure in either tier

Platform-protected, explicitly forbidden, or unsafe. A design that needs one is redesigned, or it
becomes a Public Cloud Service Request. Never a workaround, and never disabling a policy.

- R1, R2: Canada Central or Canada East, resource in a group in its own region.
- R4 to R12: no authoring of virtual networks, peering, route tables, gateways or private DNS zones;
  no public IPs; no service endpoints; subnets only with their NSG in one call and private; no
  inbound 22 or 3389 from the internet.
- R18: HTTPS only, TLS 1.2 or later.
- R24: do not delete the `setbypolicy` diagnostic setting.
- R27, in part: never grant Owner, and never assign a privileged role to anyone but the pipeline's own
  managed identity. In production R27 has no departure at all (below).
- R31: OIDC through `azure/login`; no stored cloud credential, no personal access token.
- From this skill: no secret in the repository, a file the agent reads, or the conversation; no real
  personal information in a sandbox; approvals by a human.

### Class B: a departure is allowed in sandbox, and blocks production

The landing zone may or may not enforce these in a given subscription. In sandbox, propose the
departure, record it (below), get approval, and let the canary show whether policy accepts it. In
production, any of these is a blocker.

- R14: Application Gateway (WAF_v2, Prevention) is the way to expose an application to the internet.
- R19: PaaS services with public network access disabled, reached over private endpoints.
- R20 to R23: the hardening of storage, Key Vault, SQL and customer-managed keys where those
  services are used.
- R21, R26: secrets in Key Vault with RBAC, none in pipeline variables or app settings.
- R25: the preference order for workload authentication where a higher one is available.
- R32: self-hosted runners inside the network for jobs that reach private data services.
- R3: tags, where the design would fight inheritance.
- R27: a direct Contributor assignment (the rule says privileged roles come only through
  `DO_PuC_Azure_Live_{plate}_{Role}` group membership). Sandbox may assign Contributor directly to the
  pipeline's managed identity, and only that, with these limits:
  - Contributor only, never Owner, never to a person or any other identity.
  - Scope: the environment's resource group, pre-created in the bootstrap. Subscription scope is a
    separate, wider departure: list what else lives in the subscription (other groups, an existing
    SRE agent) and have the human approve that line by name.
  - Contributor cannot create role assignments, so the agent's read-only roles are still created by a
    person in the bootstrap, or by a conditioned User Access Administrator.
  - It is attempted, not assumed. If the landing zone denies it, the entry becomes `denied-by-policy`
    and the design falls back to non-privileged roles on the resource group (`bootstrap.md`).
  - `productionNeeds`: non-privileged or custom roles at the resource group, or platform-owned group
    membership.

### Class C: additions required for production

Not in the rule list, and not required in sandbox.

- A production subscription, and a GitHub environment with required reviewers, deployment limited to
  a protected branch, and signed commits on it.
- Database high availability and backups sized to the recovery needs; zone redundancy where offered.
- Diagnostic settings to the central workspace, alerts that page a person, and a runbook.
- A rollback procedure that has been tried, and a capacity estimate.
- SRE agent run mode `ReadOnly` or `Review`; never `Autonomous`.
- A custom domain and certificate through the gateway.
- The evidence references from the question above.

## Policy has the last word

A tier does not relax policy. In sandbox, a Class B departure that policy denies has status
`denied-by-policy` and must be redesigned or escalated; it is not a pass. A sandbox pass proves
nothing about production, because production subscriptions can sit under stricter policy. Record
which denials the canary found: they become the production design's constraints.

## Deviation register

Every sandbox departure goes in three places, kept in step: the plan's "Deviations" section,
`state.json` `deviations` (schema: `schemas/state.schema.json`), and the hand-off README.

Each entry: the rule number, what the design does instead, the resource, why, what production needs
in its place (`productionNeeds`), and a status: `proposed`, then `approved` (with who and when, at
the plan gate), `denied-by-policy` (after the canary), or `resolved` (the departure was removed).
Never extend an approved entry to another resource without a new approval.

## What each phase does by tier

| Phase | Sandbox | Production |
| --- | --- | --- |
| 0 | Ask tier, confirm synthetic data, subscription guard | Ask tier, record the evidence references, subscription guard |
| 1 Scan | As is | As is; also note data classification and anything that handles personal information |
| 2 Plan | Add a "Rule compliance" table and a "Deviations" section | The same table; every row must be compliant or not applicable. A departure is listed as a blocker with the request or exception that would clear it. |
| 3 Gate | Human approves the plan and each deviation | A plan with a departure cannot be approved. A human approves the compliance table and the gap list. |
| 4 Apply | Class B departures attempted; the canary records denials | Only what has a compliant template; see below |
| 5 Bootstrap | Owner is never assigned. A direct Contributor for the pipeline identity is a recorded R27 deviation; secrets held as GitHub environment secrets are an R21/R26 deviation | Non-privileged roles at the narrowest scope, a pre-created resource group, and platform-owned group membership where a privileged role is needed |
| 6 Workflow | Manual or any trigger the user picks | Environment with required reviewers; protected-branch trigger only; self-hosted runner where private data services are touched |
| 7 Verify | As in `verification.md` | The same, plus each Class C item |
| 8 Hand off | README lists deviations and what production needs | README lists the compliance evidence and what remains |

## Production path today

The templates here build a sandbox. None of these exist yet: a Container Apps environment
integrated with a landing-zone subnet, private endpoints for Postgres, Key Vault and storage, an
Application Gateway with WAF in Prevention mode, Key Vault with secret references, Entra
authentication to the database, a self-hosted runner pipeline, and the Class C items.

So on the production tier, phases 0 to 3 run in full and produce a verified plan, the compliance
table, and a gap list of what the design needs and what has no template. Stop there, say so, and let
the user decide whether to build the missing pieces, raise the service requests, or deploy a sandbox
instead. Do not adapt a sandbox template to look compliant.

## Promotion

A sandbox does not become production by changing a parameter. Promotion is a new run at the
production tier against the production subscription, using the sandbox's deviation register as the
list of things to replace and its canary denials as known constraints.
