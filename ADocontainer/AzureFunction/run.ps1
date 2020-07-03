using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

#Check if a build is queued before launching a container
#You need to put the key in keyvault
$buildapikey = (Get-AzKeyVaultSecret -VaultName adocontainer -Name GetBuilds).SecretValueText
$ADOOrganization = 'yourorg'
$ADOProject = 'Project'

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

# Interact with query parameters or the body of the request.
$name = 'jekyllcontainerado'

$rand = Get-Random -Maximum 1000000
#You don't really need some of this anymore, was left over from the sample but it shows how this could be worked on more.
$body = "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response."
$agentname = 'dockerlinuxjek' + $rand
$resourcegroupname = 'ContainerAgent'

$dockerenv = @{
    AZP_URL="Https://dev.azure.com/$ADOOrganization/" ;
    AZP_AGENT_NAME=$agentname ;
    AZP_POOL='Jekyll'
} 

if ($name) {
    New-AzContainerGroup -ResourceGroupName $resourcegroupname -Name $name `
        -Image gabrielmccoll/jekylladoagentminmistakes:latest -OsType linux `
        -RestartPolicy Never -EnvironmentVariable $dockerenv -AssignIdentity
    $body = "Started container group $name"
}

#The first time the container group is made, this part might take a couple mins to propograte.
#Meaning your container will fail with an error message about not being able to access the key. 
$id = (Get-AzContainerGroup -ResourceGroupName $resourcegroupname -Name $name).Identity.PrincipalId
Set-AzKeyVaultAccessPolicy -VaultName adocontainer -ObjectId $id -PermissionsToSecrets get -BypassObjectIdValidation

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
