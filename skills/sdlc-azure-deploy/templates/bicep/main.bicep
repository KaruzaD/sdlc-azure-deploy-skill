// A development and test environment on Azure Container Apps. Deployed in two passes: with
// deployApps false it creates the resource group, monitoring, the Container Apps environment and
// the database, and outputs the environment's domain; after the images are built (knowing that
// domain, if the build bakes in an address), deployApps true adds the applications and alerts.
// Skip the first pass when no image needs infrastructure output at build time.
targetScope = 'subscription'

@minLength(2)
@maxLength(12)
param environmentName string

param location string = 'canadacentral'

param deployApps bool = false

@description('Registry path of the images, without a trailing slash, for example ghcr.io/owner/repo.')
param imageRegistry string = ''
param imageTag string = 'latest'

param databaseEnabled bool = false
@secure()
param postgresAdminPassword string = ''

@description('none: no agent resources. attach: an existing agent, whose identity is in agentPrincipalId. create: this deployment creates the agent.')
@allowed(['none', 'attach', 'create'])
param sreAgentMode string = 'none'
@description('Object ID of an existing agent\'s managed identity; used when sreAgentMode is attach.')
param agentPrincipalId string = ''

param healthPath string = '/status'

var prefix = environmentName
var createAgent = sreAgentMode == 'create'
var tags = {
  environment: environmentName
  purpose: 'dev-test'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module monitoring 'modules/monitoring.bicep' = {
  scope: rg
  params: { prefix: prefix, location: location, tags: tags }
}

module environment 'modules/environment.bicep' = {
  scope: rg
  params: {
    prefix: prefix
    location: location
    tags: tags
    workspaceName: monitoring.outputs.workspaceName
  }
}

module database 'modules/database-postgres.bicep' = if (databaseEnabled) {
  scope: rg
  params: {
    prefix: prefix
    location: location
    tags: tags
    uniqueSuffix: uniqueString(rg.id)
    administratorPassword: postgresAdminPassword
  }
}

module agentIdentity 'modules/agent-identity.bicep' = if (createAgent) {
  scope: rg
  params: { name: '${prefix}-sre-agent-id', location: location, tags: tags }
}

var effectiveAgentPrincipalId = createAgent ? agentIdentity!.outputs.principalId : agentPrincipalId

module agentAccess 'modules/agent-access.bicep' = if (createAgent || !empty(agentPrincipalId)) {
  scope: rg
  params: { agentPrincipalId: effectiveAgentPrincipalId }
}

module sreAgent 'modules/sre-agent.bicep' = if (createAgent) {
  scope: rg
  params: {
    name: '${prefix}-sre-agent'
    location: location
    tags: tags
    identityId: agentIdentity!.outputs.id
    managedResources: [rg.id]
  }
}

module apps 'apps.bicep' = if (deployApps) {
  scope: rg
  params: {
    prefix: prefix
    location: location
    tags: tags
    environmentId: environment.outputs.environmentId
    defaultDomain: environment.outputs.defaultDomain
    appInsightsName: monitoring.outputs.appInsightsName
    imageRegistry: imageRegistry
    imageTag: imageTag
    databaseHost: databaseEnabled ? database!.outputs.host : ''
    databaseName: databaseEnabled ? database!.outputs.databaseName : ''
    databaseUser: databaseEnabled ? database!.outputs.administratorLogin : ''
    databasePassword: postgresAdminPassword
  }
}

module alerts 'modules/alerts.bicep' = if (deployApps) {
  scope: rg
  params: {
    prefix: prefix
    location: location
    tags: tags
    appInsightsId: monitoring.outputs.appInsightsId
    targetAppId: apps!.outputs.primaryAppId
    targetUrl: apps!.outputs.primaryUrl
    healthPath: healthPath
  }
}

output resourceGroupName string = rg.name
output defaultDomain string = environment.outputs.defaultDomain
output logAnalyticsWorkspaceName string = monitoring.outputs.workspaceName
output appInsightsName string = monitoring.outputs.appInsightsName
output sreAgentName string = createAgent ? sreAgent!.outputs.name : ''
