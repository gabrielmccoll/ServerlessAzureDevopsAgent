using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Interact with query parameters or the body of the request.
$name = 'jekyllcontainerado'

$rand = Get-Random -Maximum 1000000
$body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."
$agentname = 'dockerlinuxjek' + $rand
$resourcegroupname = 'ContainerAgent'

$dockerenv = @{
    AZP_URL='https://dev.azure.com/cloudkingdoms' ;
    AZP_AGENT_NAME=$agentname ;
    AZP_POOL='Jekyll'
} 

$name = $name #+ $rand

if ($name) {
    $status = [HttpStatusCode]::OK
    New-AzContainerGroup -ResourceGroupName $resourcegroupname -Name $name `
        -Image gabrielmccoll/jekylladoagentminmistakes:latest -OsType linux `
        -RestartPolicy Never -EnvironmentVariable $dockerenv -AssignIdentity
    $body = "Started container group $name"
}

$id = (Get-AzContainerGroup -ResourceGroupName $resourcegroupname -Name $name).Identity.PrincipalId
Set-AzKeyVaultAccessPolicy -VaultName adocontainer -ObjectId $id -PermissionsToSecrets get -BypassObjectIdValidation

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
