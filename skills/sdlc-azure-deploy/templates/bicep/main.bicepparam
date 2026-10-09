using './main.bicep'

param environmentName = readEnvironmentVariable('ENVIRONMENT_NAME')
param location = readEnvironmentVariable('AZURE_LOCATION', 'canadacentral')
param deployApps = toLower(readEnvironmentVariable('DEPLOY_APPS', 'false')) == 'true'
param imageRegistry = readEnvironmentVariable('IMAGE_REGISTRY', '')
param imageTag = readEnvironmentVariable('IMAGE_TAG', 'latest')
param databaseEnabled = toLower(readEnvironmentVariable('DATABASE_ENABLED', 'false')) == 'true'
param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD', '')
param sreAgentMode = readEnvironmentVariable('SRE_AGENT_MODE', 'none')
param agentPrincipalId = readEnvironmentVariable('AGENT_PRINCIPAL_ID', '')
