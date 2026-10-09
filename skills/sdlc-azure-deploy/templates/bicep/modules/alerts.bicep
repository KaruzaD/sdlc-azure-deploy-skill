// Gives the SRE agent signals: an availability test on the health endpoint and two metric alerts.
param prefix string
param location string
param tags object
param appInsightsId string
@description('Resource ID of the externally reachable Container App.')
param targetAppId string
@description('Public URL of that app, without a trailing slash.')
param targetUrl string
param healthPath string = '/status'

resource healthTest 'Microsoft.Insights/webtests@2022-06-15' = {
  name: '${prefix}-health'
  location: location
  tags: union(tags, { 'hidden-link:${appInsightsId}': 'Resource' })
  kind: 'standard'
  properties: {
    SyntheticMonitorId: '${prefix}-health'
    Name: 'Service health'
    Enabled: true
    Frequency: 300
    Timeout: 30
    Kind: 'standard'
    RetryEnabled: true
    Locations: [
      { Id: 'us-va-ash-azr' }
      { Id: 'us-ca-sjc-azr' }
    ]
    Request: {
      RequestUrl: '${targetUrl}${healthPath}'
      HttpVerb: 'GET'
      ParseDependentRequests: false
    }
    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck: false
    }
  }
}

resource healthDown 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${prefix}-health-down'
  location: 'global'
  tags: tags
  properties: {
    description: 'The health check fails from two locations.'
    severity: 1
    enabled: true
    scopes: [healthTest.id, appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria'
      webTestId: healthTest.id
      componentId: appInsightsId
      failedLocationCount: 2
    }
  }
}

resource serverErrors 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${prefix}-5xx'
  location: 'global'
  tags: tags
  properties: {
    description: 'The application answered with server errors.'
    severity: 2
    enabled: true
    scopes: [targetAppId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ServerErrors'
          metricNamespace: 'microsoft.app/containerapps'
          metricName: 'Requests'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            { name: 'statusCodeCategory', operator: 'Include', values: ['5xx'] }
          ]
        }
      ]
    }
  }
}
