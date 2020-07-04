$ResourceGroupName = "ContainerAgentJK"
$keyVaultname = 'ContainerAgentKeyjk'
$StorageName = 'buildcontsajk'
$FunctionAppName = 'buildcontfunjk'
$location = "Uk South"

#Create Resource Group
New-AzResourceGroup -Name $ResourceGroupName -Location $location
#Create Key Vault
New-AzKeyVault -Name $keyVaultname -ResourceGroupName $ResourceGroupName -Location $location -Sku Standard
#Create Storage Account that the Function App needs
New-AzStorageAccount -Name $StorageName -ResourceGroupName $ResourceGroupName -Kind StorageV2 -SkuName Standard_LRS -AccessTier Cool -Location $location 
#Create the Function App with a System Assigned Managed Identity.
New-AzFunctionApp -ResourceGroupName $ResourceGroupName -Location $location -OSType Windows -Runtime PowerShell `
-IdentityType SystemAssigned -StorageAccountName $StorageName -Name $FunctionAppName -FunctionsVersion 3 -RunTimeVersion 6.2
#Give the Function App permission to get Secrets from the Azure Key Vault we just made. 
$id = (Get-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName).IdentityPrincipalId
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultname -ObjectId $id -PermissionsToSecrets get -BypassObjectIdValidation
##Give your own account permissions to see stuff on the keyvault
$id = $env:ACC_OID
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultname -ObjectId $id -PermissionsToSecrets list,get,set,delete -BypassObjectIdValidation