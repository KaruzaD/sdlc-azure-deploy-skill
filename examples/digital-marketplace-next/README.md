# Azure development and test environment

Bicep for the shared environment described in decision record
[0069](../../docs/decisions/0069-a-development-and-test-environment-runs-on-azure-container-apps.md):
one resource group (`rg-dmdev`) holding Log Analytics, Application Insights, a Container Apps
environment (frontend and backend in one app, Keycloak, Mailpit), PostgreSQL Flexible Server, and
alerts. It is synthetic data only and not a production target.

The environment is deployed in two passes, because the frontend image is built knowing the identity
provider's address, which depends on the environment's domain:

1. `deployApps=false` creates everything except the applications and outputs the domain.
2. After the images are built and pushed, `deployApps=true` adds the applications and alerts.

## Deploying

The workflow [deploy-azure.yml](../../.github/workflows/deploy-azure.yml) runs both passes, builds
and pushes the four images to GHCR tagged with the commit, smoke-tests the result, and adds
`rg-dmdev` to the SRE agent's managed resources. Run it manually from the Actions tab. It needs the
one-time bootstrap below.

To deploy by hand, set the variables read by [main.bicepparam](main.bicepparam)
(`POSTGRES_ADMIN_PASSWORD`, `SDLC_SANDBOX_PASSWORD`, and for the second pass `DEPLOY_APPS=true`,
`IMAGE_REGISTRY`, `IMAGE_TAG`, optionally `AGENT_PRINCIPAL_ID`) and run:

```bash
az deployment sub create --name dmdev-foundation --location canadacentral --parameters main.bicepparam
```

## One-time bootstrap

The workflow signs in to Azure through OIDC, with no stored credential. The identity it signs in as
has to exist first, and creating it needs rights the pipeline does not have, so it is documented
steps rather than automation. A user-assigned managed identity needs no Entra directory permission,
unlike an app registration.

Run these as someone who can assign roles at the subscription and on the agent's resource group.

```bash
SUB=bcca42e1-a0c9-4a0c-99dc-4c63e5728042
REPO=bcgov/digital-marketplace-next
BOOT_RG=rg-dmdev-bootstrap          # outside rg-dmdev, so tearing the environment down keeps it
AGENT_RG=csbc-sdpr-document-intelligence
AGENT=sdpr-di-agent-darian-test

az group create -n "$BOOT_RG" -l canadacentral
az identity create -g "$BOOT_RG" -n id-dmdev-deploy

# Only runs of the `dev` GitHub environment in this repository can use the identity.
az identity federated-credential create -g "$BOOT_RG" --identity-name id-dmdev-deploy \
  -n github-dev --issuer https://token.actions.githubusercontent.com \
  --subject "repo:$REPO:environment:dev" --audiences api://AzureADTokenExchange

PRINCIPAL=$(az identity show -g "$BOOT_RG" -n id-dmdev-deploy --query principalId -o tsv)
```

Roles for the identity:

```bash
# Creates rg-dmdev and everything in it (the deployment is at subscription scope).
az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role Contributor --scope "/subscriptions/$SUB"

# Creates the agent's read-only role assignments, and only those three roles.
R="acdd72a7-3385-48ef-bd42-f606fba81ae7, 43d0d8ad-25c7-4714-9337-8ba259a9fe05, 73c42c96-874c-492b-b04d-ab87d138a893"
az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" --scope "/subscriptions/$SUB" --condition-version 2.0 \
  --condition "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {$R})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {$R}))"

# Reads the agent and its identity, and updates the agent's managed resources.
az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role Reader --scope "/subscriptions/$SUB/resourceGroups/$AGENT_RG"
az role assignment create --assignee-object-id "$PRINCIPAL" --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/$SUB/resourceGroups/$AGENT_RG/providers/Microsoft.App/agents/$AGENT"
```

Contributor on the agent can also change the agent's settings, including its mode. A custom role
limited to `Microsoft.App/agents/write` would be tighter. Updating the agent's managed resources
with this identity has not been tested; if it fails on authorisation for the agent's own
user-assigned identity, also grant Managed Identity Operator on that identity.

### GitHub environment

Create an environment named `dev` in the repository (required reviewers recommended), then:

```bash
gh variable set AZURE_CLIENT_ID --env dev --body "$(az identity show -g $BOOT_RG -n id-dmdev-deploy --query clientId -o tsv)"
gh variable set AZURE_TENANT_ID --env dev --body "$(az account show --query tenantId -o tsv)"
gh variable set AZURE_SUBSCRIPTION_ID --env dev --body "$SUB"
gh variable set SRE_AGENT_ID --env dev --body "$(az resource show -g $AGENT_RG -n $AGENT --resource-type Microsoft.App/agents --query id -o tsv)"
gh secret set POSTGRES_ADMIN_PASSWORD --env dev     # prompts; generate a long random value
gh secret set SDLC_SANDBOX_PASSWORD --env dev       # the synthetic users' shared password
```

### Image visibility

The images are pulled with no registry credential, so the four GHCR packages (`backend`,
`migrations`, `idp-realm`, `frontend`) must be public. Packages published by the workflow are linked
to the repository by an image label; if they come up private, make them public once under the
package's settings, since GitHub does not offer that through its API.

## Teardown

`az group delete -n rg-dmdev` removes the environment, including the database. The bootstrap
identity lives in its own resource group and is kept.
