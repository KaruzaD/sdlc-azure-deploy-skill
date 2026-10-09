# Azure SRE Agent

The agent is `Microsoft.App/agents`, API `2026-01-01` (a preview). Microsoft documents deploying it
with Bicep and the Azure CLI, with identity, network configuration and tool policies as code.
Reference: https://learn.microsoft.com/azure/templates/microsoft.app/agents

## Confirmed in this tenant (2026-10)

- An agent created in the portal has a user-assigned identity, its own Application Insights, run
  mode `Review` and access level `Low`. `knowledgeGraphConfiguration.managedResources` starts empty.
- An existing agent can be attached to a new resource group by PATCH. The body must include
  `knowledgeGraphConfiguration.identity` as well as `managedResources`, or the API answers
  `InvalidIdentity`. The PATCH is asynchronous: `provisioningState` is `InProgress` for a few
  minutes, then `Succeeded`. The change keeps the run mode.
- Treat `managedResources` as replaced by a PATCH: read it and write back the union. Whether a PATCH
  replaces or merges the array was not tested, because the list was empty.
- Reader, Monitoring Reader and Log Analytics Reader on the resource group were granted to the
  agent's identity, and the assignments exist. Whether they are enough for the agent to see the
  application's resources and logs is S3, not yet confirmed.
- `logConfiguration.applicationInsightsConfiguration` is the agent's own telemetry, not the
  application's. Do not repoint it at the application's App Insights.
- To read App Insights data from a script, query the workspace tables (`AppRequests` and so on)
  with `az monitor log-analytics query`. `az monitor app-insights query` stops on an
  extension-install prompt.

## Not confirmed

These are the spikes. Run one only after the user agrees, say what it costs, and record the result
here and in the state file's `verifiedFacts`.

- **S1, create through Bicep.** `templates/bicep/modules/sre-agent.bicep` was written from the schema
  and has never been deployed. Questions: does it need `agentIdentity` (which asks for an Entra group,
  so a directory permission) or does it work without; does it need a Managed Identity Operator role
  on the identity; does it create its own Application Insights or need one; which regions; the
  deploying identity's required role; whether the new agent's role assignments propagate in time.
  Do it in a scratch resource group and delete it after.
- **S2, update by the pipeline's identity.** The PATCH has been run by a user with the SRE Agent
  Administrator role, never by the pipeline's identity. Find the narrowest role that allows it. If it
  fails on the agent's own identity, try Managed Identity Operator on that identity. Contributor on
  the agent works but can also change its mode; a custom role limited to `Microsoft.App/agents/write`
  is tighter.
- **S3, the agent can see the application.** Confirm by asking the agent a question about the
  environment, through its portal or its endpoint, and checking the answer names the app's resources.
- **S4, connectors.** GitHub for deployment correlation, and Azure Monitor alerts as the incident
  source. Out of scope for now; the agent still works without them.

## Choices to put to the user

- **Create or attach.** Attach reuses an agent that already holds history and settings; create gives
  a clean agent per environment but costs agent units and needs S1 first.
- **Run mode.** `Review` keeps writes behind a human approval and is the default. `ReadOnly` is
  stricter. `Autonomous` lets it act on its own; do not offer it unless asked.
- **Where it lives.** An attached agent stays in its own resource group. A created one goes in the
  environment's resource group, which makes it a resource of the thing it watches; ask whether to
  separate them.

## Verify

After attaching or creating, confirm: `provisioningState` is `Succeeded`, `runningState` is
`Running`, the resource group is in `managedResources`, `actionConfiguration.mode` is unchanged, and
the three roles exist on the resource group. Then S3.
