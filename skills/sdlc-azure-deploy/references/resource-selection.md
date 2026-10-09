# From inventory to resources

Every row says what an inventory finding requires. A resource with no finding behind it has no place
in the plan.

| Finding | Resource | Notes |
| --- | --- | --- |
| Any deployment | Resource group `rg-<env>`, Log Analytics workspace, workspace-based Application Insights, Container Apps environment with logs to the workspace | `modules/monitoring.bicep`, `modules/environment.bicep`. Give the environment its own workspace so its data stays apart from the agent's. |
| A service with `external: true` | A Container App with external HTTPS ingress on the default domain | `modules/app.bicep` |
| A service that only another service calls, over HTTP | A second container in the same app, reached on `localhost` | Internal plain-HTTP ingress between apps is denied by policy. Share an app when a service only serves one other. |
| A service that must be reached by name from other apps over TCP (mail, a cache) | A Container App with an additional TCP port mapping, internal | Plain HTTP is the problem; TCP is not. |
| A migration job | An init container of the app that needs the schema | Runs before the app starts, in the same environment, so it needs no route from the pipeline to the database. |
| `postgres` | PostgreSQL Flexible Server, Burstable B1ms, version from the code, TLS required in the connection string | `modules/database-postgres.bicep`. Public access departs from R19; see `landing-zone-bcgov.md`. |
| Other datastores | Not supported yet. Say so and stop. | Redis, SQL Server and blob each need their own module. |
| Own identity provider needed | An identity provider as a Container App; render its realm or config from a template at start (init container into an `EmptyDir`) with the public address filled in | The issuer the app verifies must equal the address a browser reaches. Set the provider's hostname and proxy-header settings. |
| Sends mail | A mail catcher (Mailpit) with SMTP internal and its UI external, for dev and test | Or a real relay if the user asks. A public catcher UI shows every message: ask about exposure. |
| `persistence` | Azure Files volume, or accept loss | `EmptyDir` is lost on restart. Ask whether it matters in dev. |
| `buildTime` item with `dependsOnInfra` | Two-pass deployment | Build the image after the foundation pass knowing the address. |
| `telemetry.sdk` is `none` | Code change: the Azure Monitor OpenTelemetry distro, started only when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set, imported before the web framework | Logs reach the workspace without it; requests, dependencies and exceptions need it. Language-specific: Node is proven; others are not. |
| Any `healthPath` | Availability test and alerts on it | `modules/alerts.bicep` |
| SRE agent attach or create | Role assignments for the agent's identity; for create, the agent and its identity | `modules/agent-access.bicep`, `modules/sre-agent.bicep`, `references/sre-agent.md` |
| Images | Registry per the interview | Public GHCR avoids a pull credential; the package must be public. |

## Code changes the plan may need

Each needs its own evidence and reasoning in the plan, and is made on a branch.

- Read an address from an environment variable where it is hard-coded.
- Start telemetry when its connection string is present.
- A health route, if none exists (a deployment cannot be probed without one).
- A realm or config template parameterised by the public address.
- An `org.opencontainers.image.source` label (added by the pipeline's build, not the Dockerfile).
- Database connection with TLS required.

## Cost

Estimate monthly cost from the SKUs chosen and show it at the approval gate, and say what to turn
down when idle. The Container Apps environment with one replica each, a Burstable database and a
workspace are the usual contributors; the SRE agent has its own unit-based charge.
