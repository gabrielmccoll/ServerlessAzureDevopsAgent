using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

#Check if a build is queued before launching a container
#You need to put the key in keyvault
$VaultName = 'ContainerAgentKeyjk'
$buildapikey = (Get-AzKeyVaultSecret -VaultName $VaultName -Name GetBuilds).SecretValueText
$ADOOrganization = 'Your Org' #Not the full URL
$ADOProject = 'Jekyll Blog' #or whatever the project name is. 
$resourcegroupname = 'ContainerAgentJK'
#You don't really need the body anymore, was left over from the sample but it shows how this could be worked on more.
$body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."

#Make the name unique for the registered agent
$rand = Get-Random -Maximum 1000000
$agentname = 'dockerlinuxjek' + $rand

#environmental variables for the docker container to use once it's spun up
$dockerenv = @{
    AZP_URL="Https://dev.azure.com/$ADOOrganization/" ;
    AZP_AGENT_NAME=$agentname ;
    AZP_POOL='Jekyll';
    AZ_SECRET_NAME='adocontaineragent';
    AZ_KEY_VAULT=$VaultName
} 

$containerinstancename = 'jekyllcontainerado2'

#the API token needs to be in base64 to use to invoke the web request
function Test-Build {
    $url = "https://dev.azure.com/$ADOOrganization/$ADOProject/_apis/build/builds?statusFilter=notstarted&api-version=5.1"
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$buildapikey"))
    $result = Invoke-RestMethod -Uri $url -Method Get -ContentType "application/json" -Headers @{Authorization = "Basic $token"}
    $result.value
}

#Checks if the build is queued or not.
#This makes sure a container doesn't get spun up without a build.
#potentially wracking up costs. 
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

# Interact with query param2eters or the body of the request.
#this will be the name of the Azure Container Instance

if ($containerinstancename) {
    New-AzContainerGroup -ResourceGroupName $resourcegroupname -Name $containerinstancename `
        -Image gabrielmccoll/jekylladoagentminmistakes:latest -OsType linux `
        -RestartPolicy Never -EnvironmentVariable $dockerenv -AssignIdentity
    $body = "Started container group $containerinstancename"
}

#The first time the container group is made, this part might take a couple mins to propograte.
#Meaning your container will fail with an error message about not being able to access the key. 
$id = (Get-AzContainerGroup -ResourceGroupName $resourcegroupname -Name $containerinstancename).Identity.PrincipalId
Set-AzKeyVaultAccessPolicy -VaultName $VaultName -ObjectId $id -PermissionsToSecrets get -BypassObjectIdValidation

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
