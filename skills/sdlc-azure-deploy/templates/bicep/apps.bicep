// Replace this one example app with the project's applications, taken from the approved plan.
// Each app is one call to modules/app.bicep. Pass anything the build needs from the environment
// (an identity provider's address, say) through outputs of main.bicep, not through this file.
param prefix string
param location string
param tags object
param environmentId string
param defaultDomain string
param appInsightsName string
param imageRegistry string
param imageTag string

param databaseHost string
param databaseName string
param databaseUser string
@secure()
param databasePassword string

var appName = '${prefix}-web'
var appUrl = 'https://${appName}.${defaultDomain}'

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

module web 'modules/app.bicep' = {
  name: appName
  params: {
    name: appName
    location: location
    tags: tags
    environmentId: environmentId
    external: true
    targetPort: 8080
    secrets: [
      { name: 'appinsights-connection', value: appInsights.properties.ConnectionString }
      #disable-next-line use-secure-value-for-secure-inputs // built from the secure password
      { name: 'database-url', value: empty(databaseHost) ? 'unused' : 'postgresql://${databaseUser}:${databasePassword}@${databaseHost}:5432/${databaseName}?sslmode=require' }
    ]
    containers: [
      {
        name: 'web'
        image: '${imageRegistry}/web:${imageTag}'
        resources: { cpu: json('0.5'), memory: '1Gi' }
        env: [
          { name: 'PORT', value: '8080' }
          { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', secretRef: 'appinsights-connection' }
          { name: 'OTEL_SERVICE_NAME', value: appName }
          { name: 'DATABASE_URL', secretRef: 'database-url' }
        ]
        probes: [
          { type: 'Liveness', httpGet: { path: '/status', port: 8080 }, periodSeconds: 30 }
          { type: 'Readiness', httpGet: { path: '/status', port: 8080 }, periodSeconds: 10 }
        ]
      }
    ]
  }
}

output primaryAppId string = web.outputs.id
output primaryUrl string = appUrl
