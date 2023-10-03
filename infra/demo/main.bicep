targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'

param appServicePlanName string = ''
param backendServiceName string = ''
param resourceGroupName string = ''
param includeSlotName string = ''

param searchServiceName string = 'cognitivesearchopenaipparpas'
param searchServiceKey string = ''
param searchIndexName string = 'azuresql-index'
param searchUseSemanticSearch bool = false
param searchSemanticSearchConfig string = 'default'
param searchTopK int = 5
param searchEnableInDomain bool = false
param searchContentColumns string = 'ProductID|ProductName|Description|CatalogDescription|ProductNumber|ProductModelName|Color|StandardCost|ListPrice|Size|Weight|Category'
param searchFilenameColumn string = 'ProductName'
param searchTitleColumn string = 'ProductName'
param searchUrlColumn string = 'ProductName'

param openAiResourceName string = 'openai-poc-pparpas'
param openAiKey string = ''
param openAIModel string = 'test'
param openAIModelName string = 'gpt-35-turbo'
param openAITemperature int = 0
param openAITopP int = 1
param openAIMaxTokens int = 1000
param openAIStopSequence string = ''
param openAISystemMessage string = 'You are an AI eCommerse assistant that helps people find products.'
param openAIApiVersion string = '2023-06-01-preview'
param openAIStream bool = true

// Used for the Azure AD application
param authClientId string
@secure()
param authClientSecret string 

// Used for Cosmos DB
// param cosmosAccountName string = ''

@description('Id of the user or app to assign application roles')
// param principalId string = ''

var abbrs = loadJsonContent('../abbreviations.json')
var resourceToken = '${toLower(environmentName)}-${toLower(uniqueString(subscription().id, environmentName, location))}'
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan '../core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'S1'
      capacity: 1
    }
    kind: 'linux'
  }
}

// The application frontend
var appServiceName = !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesAppService}backend-${resourceToken}'
var authIssuerUri = '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'
module backend '../core/host/appservice.bicep' = {
  name: 'web'
  scope: resourceGroup
  params: {
    name: appServiceName
    location: location
    tags: union(tags, { 'azd-service-name': 'backend' })
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    scmDoBuildDuringDeployment: true
    managedIdentity: true
    authClientSecret: authClientSecret
    authClientId: authClientId
    authIssuerUri: authIssuerUri
    includeSlotName: includeSlotName
    appSettings: {
      // search
      AZURE_SEARCH_INDEX: searchIndexName
      AZURE_SEARCH_SERVICE: searchServiceName
      AZURE_SEARCH_KEY: searchServiceKey
      AZURE_SEARCH_USE_SEMANTIC_SEARCH: searchUseSemanticSearch
      AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG: searchSemanticSearchConfig
      AZURE_SEARCH_TOP_K: searchTopK
      AZURE_SEARCH_ENABLE_IN_DOMAIN: searchEnableInDomain
      AZURE_SEARCH_CONTENT_COLUMNS: searchContentColumns
      AZURE_SEARCH_FILENAME_COLUMN: searchFilenameColumn
      AZURE_SEARCH_TITLE_COLUMN: searchTitleColumn
      AZURE_SEARCH_URL_COLUMN: searchUrlColumn
      // openai
      AZURE_OPENAI_RESOURCE: openAiResourceName
      AZURE_OPENAI_MODEL: openAIModel
      AZURE_OPENAI_MODEL_NAME: openAIModelName
      AZURE_OPENAI_KEY: openAiKey
      AZURE_OPENAI_TEMPERATURE: openAITemperature
      AZURE_OPENAI_TOP_P: openAITopP
      AZURE_OPENAI_MAX_TOKENS: openAIMaxTokens
      AZURE_OPENAI_STOP_SEQUENCE: openAIStopSequence
      AZURE_OPENAI_SYSTEM_MESSAGE: openAISystemMessage
      AZURE_OPENAI_PREVIEW_API_VERSION: openAIApiVersion
      AZURE_OPENAI_STREAM: openAIStream
    }
  }
}
