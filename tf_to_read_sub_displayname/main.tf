variable "entra_tenant_id" {
  type     = string
  nullable = false
}
variable "az_sub_id" {
  type     = string
  nullable = false
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=5.13.0"
    }
  }
}

provider "azurerm" {
  # Some common error messages with which `terraform plan` against this block might fail:
  # 1.
  #    Error: unable to build authorizer for Resource Manager API: 
  #    could not configure AzureCli Authorizer: 
  #    obtaining subscription ID: obtaining account details: 
  #    running Azure CLI: exit status 1: 
  #    ERROR: Please run 'az login' to setup account.
  # (Explainig this one is simple -- you seem to have run `az logout` and forgotten.
  # Run `az login` again!)
  features {}
  alias                           = "demo"
  tenant_id                       = var.entra_tenant_id
  subscription_id                 = var.az_sub_id
  resource_provider_registrations = "none"
}

data "azurerm_client_config" "current_azurerm_config" {
  provider = azurerm.demo
  lifecycle {
    postcondition {
      condition     = (coalesce(self.subscription_id, "") == var.az_sub_id)
      error_message = "AzureRM login state subscription ID is not as passed in."
    }
  }
}

data "azurerm_subscription" "current_sub_details" {
  # Some common error messages with which `terraform plan` against this block might fail:
  # 1.
  #    could not configure AzureCli Authorizer: 
  #    the provided subscription ID "..." is not known by Azure CLI
  # (this means your `az login` is pointed at a different tenant 
  # or you don't have access to see that subscription's existence)
  # 2. 
  #    Error: retrieving Subscription (Subscription: "..."):
  #    authorizing request: running Azure CLI: exit status 1: 
  #    ERROR: SubError: basic_action V2Error: 
  #    invalid_grant AADSTS50078: Presented multi-factor authentication has expired 
  #    due to policies configured by your administrator, you must refresh your 
  #    multi-factor authentication to access '797f4846-ba00-4fd7-ba43-dac1f8f63013'
  #    ...
  #    Run the command below to authenticate interactively; additional arguments may be added as needed:
  #    ...
  # (this means not only that your last-MFA'ed `az login` has expired, 
  # but that your company's Entra admins have introduced a Conditional Access policy 
  # saying that your Entra user is not allowed to do 
  # any interactive work at all against Azure through the Azure CLI -- not even 
  # read the display name of a subscription.  This is stricter than 
  # Microsoft's default Conditional Access policies, at least as of 11/16/2026).
  provider        = azurerm.demo
  subscription_id = data.azurerm_client_config.current_azurerm_config.subscription_id
}

output "subscription_display_name" {
  value = data.azurerm_subscription.current_sub_details.display_name
}
