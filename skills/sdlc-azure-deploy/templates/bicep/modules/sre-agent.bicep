// UNVERIFIED: written from the Microsoft.App/agents@2026-01-01 schema and compared with an agent
// created in the portal. It has never been deployed. Run spike S1 in references/sre-agent.md
// before relying on it, and update that file with what the spike shows.
param name string
param location string
param tags object

@description('Resource ID of the user-assigned identity the agent runs as.')
param identityId string

@allowed(['ReadOnly', 'Review', 'Autonomous'])
param mode string = 'Review'

@allowed(['Low', 'High'])
param accessLevel string = 'Low'

@description('Resource group IDs the agent should manage.')
param managedResources array = []

@allowed(['Stable', 'Preview'])
param upgradeChannel string = 'Stable'

resource agent 'Microsoft.App/agents@2026-01-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identityId}': {} }
  }
  properties: {
    actionConfiguration: {
      identity: identityId
      mode: mode
      accessLevel: accessLevel
    }
    knowledgeGraphConfiguration: {
      identity: identityId
      managedResources: managedResources
    }
    upgradeChannel: upgradeChannel
  }
}

output id string = agent.id
output name string = agent.name
