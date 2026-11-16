# Reminder:  to run this Terraform code successfully, 
# you must be logged into the Azure CLI as an Entra principal that has adequate permissions to manipulate 
# both Azure and Entra.

Push-Location("$PsScriptRoot")

terraform init

terraform plan `
    -var entra_tenant_id="$([Environment]::GetEnvironmentVariable('DEMOS_my_entra_tenant_id'))" `
    -var az_sub_id="$([Environment]::GetEnvironmentVariable('DEMOS_my_azure_subscription_id'))" 

Pop-Location
