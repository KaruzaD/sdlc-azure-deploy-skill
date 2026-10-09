# BC Gov landing-zone profile

The only profile so far. Policy in the landing zone overrides RBAC: Owner does not bypass a Deny.
When a design conflicts with a rule here, the design changes. Anything that cannot be met inside the
guardrails is a Public Cloud Service Request to the platform team, not a workaround.

Sources: the `bcgov-azure` skill (`CONVENTIONS.md`, rules R1 to R33, cited below), the BC Gov public
cloud tech docs it links, and what the first deployment actually hit. Read `CONVENTIONS.md` if it is
installed; this file does not replace it.

## Observed

From the first deployment (subscription `dbc1c3-dev`, Canada Central). Re-check, since each
subscription can differ.

| What | Result |
| --- | --- |
| A Container App with plain-HTTP (`allowInsecure: true`) ingress, as an internal backend would need | Denied by policy `Enforce-TLS-SSL-Q225`. Preflight validation had passed. The fix was to run the backend as a second container in the same app, reached on `localhost`. `templates/bicep/modules/app.bicep` fixes `allowInsecure` to false. |
| Container Apps environment with the default domain and public HTTPS ingress | Created |
| PostgreSQL Flexible Server, public access, `0.0.0.0` firewall rule | Created |
| Role assignments by the user | The user's Owner comes from a group at the management group `dbc1c3`, not a direct assignment |
| Policy visible through `az policy assignment list` | Four subscription assignments, none relevant. Management-group policy is not visible from here, so preflight cannot list what applies. |

## Where the golden example departs from the rules

The first deployment worked, but a stricter subscription may deny these. Each needs a recorded
exception from the platform team, or a redesign, before it is used on another project. The canary
deployment (phase 4) shows which are denied where you are deploying.

| Rule | What the example did | What to do instead, or ask |
| --- | --- | --- |
| R14: Application Gateway is the only supported way to expose an app to the internet | Public Container Apps default domain, no gateway (the requester's choice) | Ask whether a dev or test environment may skip it, and record the answer |
| R19: PaaS created with public network access disabled | Public Postgres with the Azure-services firewall rule | Private endpoint needs a VNet-integrated environment on a landing-zone subnet (R4, R6, R13). Ask first. |
| R21, R26: secrets in Key Vault only; none in pipeline variables | Container App secrets, and a Postgres password held as a GitHub environment secret | Key Vault with RBAC, and a managed identity to read it. Better still, Entra authentication to the database so there is no password. The app may need a code change. |
| R27: no direct Owner or Contributor assignment at any scope | The bootstrap assigns Contributor on the subscription directly to the pipeline identity. Not tested against R27. | Pre-create the resource group, deploy at its scope, and give the identity non-privileged roles, or a custom role. Or ask the platform team to add the identity to the group that carries the role. Not decided. |

A project may carry approved deviations. Record them with the rule number, the resource and the
approval, so a later review flags only new ones. Never extend one to more resources without a new
approval.

## Rules the templates already follow

- R1, R2: Canada Central or Canada East; a resource lives in a group in its own region.
- R3: tags are inherited from the subscription; do not manage them in a way that fights that.
- R18: HTTPS only, TLS 1.2 or later.
- R25, R30: managed identity first, then a federated credential. No app registration, so no
  My Service Centre request for this pipeline. If a project's own sign-in needs one, that is a
  request through My Service Centre, never self-service.
- R31: GitHub Actions signs in with OIDC through `azure/login`.
- R24: do not delete the `setbypolicy` diagnostic setting; add your own.

## Check at preflight and canary

Allowed locations, required tags, whether public PaaS access is denied, whether a Container Apps
environment must be VNet-integrated, private DNS arrangements, and whether Defender or other
policy adds resources. Report each as confirmed, denied or not testable.

## Escalation

Stop and tell the user a Public Cloud Service Request is needed for: more IP space than the default,
spoke-to-spoke connectivity, firewall rules (including cross-subscription runner access), route
tables, custom private DNS zones, on-premises connectivity, any policy exception. Service Desk:
https://citz-do.atlassian.net/servicedesk/customer/portal/3
