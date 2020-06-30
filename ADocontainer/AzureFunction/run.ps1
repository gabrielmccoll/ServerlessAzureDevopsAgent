using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)



#Check if a build is queued before launching a container
#You need to put the key in keyvault
$buildapikey = (Get-AzKeyVaultSecret -VaultName adocontainer -Name GetBuilds).SecretValueTex

function Test-Build {
    $url = "https://dev.azure.com/cloudkingdoms/Jekyll%20Blog/_apis/build/builds?statusFilter=notstarted&api-version=5.1"
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$buildapikey"))
    $result = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json" -Headers @{Authorization = "Basic $token"}
    $result.value
}

#Checks if the build is queued or not for 
$count = 0
do {
    $buildqueued = Test-Build
    if ($null -eq $buildqueued) {
        start-sleep 3
        $count = $count + 3
        if($count -gt 9) {
            Write-Error 'No Build is queued therefore no container will be started'
            exit
            
        }
    }
} until ($null -ne $buildqueued)




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
