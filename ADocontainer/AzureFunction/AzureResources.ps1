$ResourceGroupName = "ContainerAgent2"
$keyVaultname = 'ContainerAgentKey'
$StorageName = 'buildcontsa'
$FunctionAppName = 'buildcontfun'
$location = "Uk South"

New-AzResourceGroup -Name $ResourceGroupName -Location $location
New-AzKeyVault -Name $keyVaultname -ResourceGroupName $ResourceGroupName -Location $location -Sku Standard
New-AzStorageAccount -Name $StorageName -ResourceGroupName $ResourceGroupName -Kind StorageV2 -SkuName Standard_LRS -AccessTier Cool -Location $location 
New-AzFunctionApp -ResourceGroupName $ResourceGroupName -Location $location -OSType Windows -Runtime PowerShell `
-IdentityType SystemAssigned -StorageAccountName $StorageName -Name $FunctionAppName -FunctionsVersion 3 -RunTimeVersion 6.2
$id = (Get-AzFunctionApp -Name $FunctionAppName -ResourceGroupName $ResourceGroupName).IdentityPrincipalId
Set-AzKeyVaultAccessPolicy -VaultName $keyVaultname -ObjectId $id -PermissionsToSecrets get -BypassObjectIdValidation
