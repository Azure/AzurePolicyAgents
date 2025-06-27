param(
    [string] $modelDeploymentName,
    [string] $azAIProxyInstructions,
    [string] $azAIProxyUri,
    [string] $openApiDefinitionUri,
    [string] $azAIAgentUri,
    [string] $azAgentName,
    [string] $tenantId
)
    
try {
    Write-Host "Requesting Azure access token..."
    $TokenRequest = (Get-AzAccessToken -ResourceUrl "https://ai.azure.com/").Token
    Write-Host "Access token retrieved successfully."

    Write-Host "Validating input"
    Write-Host "Agent name is: $azAgentName"
    Write-Host "Agent instruction is: $azAIProxyInstructions"
    Write-Host "OpenAPI definition URI is: $openApiDefinitionUri"
    Write-Host "Azure AI Proxy URI is: $azAIProxyUri"
    Write-Host "Azure AI Agent URI is: $azAIAgentUri"
    Write-Host "Tenant ID is: $tenantId"

    Write-Host "Downloading Swagger file from $openApiDefinitionUri..."
    $swaggerDefinition = Invoke-RestMethod -Uri $openApiDefinitionUri -UseBasicParsing

    Write-Host "Modifying the URL in the Swagger file..."
    $swaggerDefinition.servers[0].url = $azAIAgentUri
    Write-Host "Successfully modified the URL."

    Write-Host "Updating the tokenUrl in the Swagger file with tenantId..."
    $swaggerDefinition.components.securitySchemes.oauth2ManagedIdentity.flows.clientCredentials.tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    Write-Host "Successfully updated the tokenUrl with tenantId."

    Write-Host "Converting the modified Swagger definition to JSON..."
    $modifiedSwaggerJson = $swaggerDefinition | ConvertTo-Json -Depth 100
    Write-Host "Successfully converted the Swagger definition to JSON."

    $localPath = 'modifiedSwagger.json'
    Write-Host "Saving the modified Swagger file to $localPath..."
    $modifiedSwaggerJson | Set-Content -Path $localPath -Encoding utf8
    Write-Host "Successfully saved the modified Swagger file."

    Write-Host "Creating the agent..."
    $authHeader = @{  
        Authorization = "Bearer $($TokenRequest)"  
        "x-ms-enable-preview" = "true"
    }

    $bodyCreateAgent = @{
        instructions = $azAIProxyInstructions
        name = $azAgentName
        model = $modelDeploymentName
    } | ConvertTo-Json -Depth 100

    $agentUri = "$azAIProxyUri/assistants?api-version=2025-05-15-preview"

    $createAgentResponse = Invoke-RestMethod -Uri $agentUri -Method Post -Headers $authHeader -ContentType "application/json" -Body $bodyCreateAgent
    Write-Host "Agent creation response: $($createAgentResponse | ConvertTo-Json -Depth 100)"

    Write-Host "Adding the OpenAPI definition to the agent..."
    $openAPISpec = Get-Content -Path $localPath -Raw

    $body = @{
        tools = @(
            @{
                type = "openapi"
                openapi = @{
                    name = "AzureAIAgentAPI"
                    description = "Open API for Azure AI Agent"
                    auth = @{
                        type = "managed_identity"
                        security_scheme = @{
                            audience = "https://ai.azure.com/"
                        }
                    }
                    spec = $openAPISpec | ConvertFrom-Json
                }
            }
        )
    } | ConvertTo-Json -Depth 100

    $agentUri = "$azAIProxyUri/assistants/$($createAgentResponse.id)?api-version=2025-05-15-preview"
    $response = Invoke-RestMethod -Uri $agentUri -Method Post -Headers $authHeader -ContentType "application/json" -Body $body
    Write-Host "Successfully added OpenAPI definition to the agent. Response: $($response | ConvertTo-Json -Depth 100)"
}
catch {
    Write-Host "Error occurred: $_"
    exit 1
}