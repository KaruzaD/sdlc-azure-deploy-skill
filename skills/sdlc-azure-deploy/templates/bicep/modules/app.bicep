// One Container App. The arrays pass straight through, so a project describes its containers,
// init containers, secrets and volumes in apps.bicep without this module changing.
param name string
param location string
param tags object
param environmentId string

param ingressEnabled bool = true
param external bool = false
param targetPort int = 0
@allowed(['http', 'http2', 'tcp'])
param transport string = 'http'
param additionalPortMappings array = []

param secrets array = []
param initContainers array = []
param containers array
param volumes array = []
param minReplicas int = 1
param maxReplicas int = 1

// allowInsecure is fixed at false: the landing zone denies a Container App that allows plain HTTP.
resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: ingressEnabled
        ? {
            external: external
            targetPort: targetPort
            transport: transport
            allowInsecure: false
            additionalPortMappings: additionalPortMappings
          }
        : null
      secrets: secrets
    }
    template: {
      initContainers: initContainers
      containers: containers
      volumes: volumes
      scale: { minReplicas: minReplicas, maxReplicas: maxReplicas }
    }
  }
}

output id string = app.id
output name string = app.name
output fqdn string = ingressEnabled ? app.properties.configuration.ingress.fqdn : ''
