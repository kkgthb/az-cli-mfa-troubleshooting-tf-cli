variable "entra_tenant_id" {
  type     = string
  nullable = false
}
variable "az_sub_id" {
  type     = string
  nullable = false
}
variable "workload_nickname" {
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
  provider        = azurerm.demo
  subscription_id = data.azurerm_client_config.current_azurerm_config.subscription_id
  lifecycle {
    postcondition {
      condition     = (coalesce(self.subscription_id, "") == data.azurerm_client_config.current_azurerm_config.subscription_id)
      error_message = "Fetched-subscription ID is not as passed in."
    }
    postcondition {
      condition     = (coalesce(self.display_name, "") != "")
      error_message = "Fetched-subscription display name is blank but should not be."
    }
  }
}

resource "azurerm_resource_group" "my_example_rg" {
  # PLAN errors:
  # Some common error messages with which `terraform plan` against this block might fail:
  # 1. 
  #    Error: checking for presence of existing Resource Group
  #    ...
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
  # saying that your Entra user is not allowed to do much of any (if any) 
  # any interactive work at all against Azure through the Azure CLI -- not even 
  # create a new resource group.  This is stricter than 
  # Microsoft's default Conditional Access policies, at least as of 11/16/2026).
  # 
  # APPLY errors:
  # Some common error messages with which `terraform apply` against this block might fail:
  # 1. 
  #    Error: creating "Resource Group ...)": 
  #    unexpected status 401 (401 Unauthorized) with error: 
  #    RequestDisallowedByAzure: Resource '...' was disallowed by Azure: 
  #    You are receiving this error because you tried to create, update or delete 
  #    Azure resources without authenticating through MFA. 
  #    User accounts must be authenticated through MFA to manage your resources. 
  #    To resolve this error, go to Search - Microsoft Bing
  # (this is what https://katiekodes.com/azure-mfa-claims-challenge/ talks about -- 
  # in October 2026, Microsoft made it so no human Entra user is allowed to do CRUD operations 
  # against Azure, using Azure Resource Manager APIs, the `az` CLI, etc., 
  # without presenting a login token that was obtained using multi-factor authentication.
  # Hopefully, Terraform's `azurerm` provider will stop obscuring what ought to be a 
  # much more understandable suggestion along the lines of:
  #  AADSTS50076: Due to a configuration change made by your administrator, 
  #  or because you moved to a new location, 
  #  you must use multi-factor authentication to access '797f4846-ba00-4fd7-ba43-dac1f8f63013'.
  #  ...
  #  Run the command below to authenticate interactively; additional arguments may be added as needed:
  #  ...
  # (Or who knows, maybe it is already fixed -- haven't personally yet gotten a chance to test in a tenant 
  # where I'd run into this exact issue again.  11/16/2026.)
  provider = azurerm.demo
  name     = "${var.workload_nickname}-rg-demo"
  location = "centralus"
  lifecycle {
    postcondition {
      condition     = (coalesce(self.id, "") != "")
      error_message = "New RG ID is blank but should not be."
    }
    postcondition {
      condition     = (coalesce(self.name, "") == "${var.workload_nickname}-rg-demo")
      error_message = "New RG name is not as passed in."
    }
  }
}
output "rg_output" {
  value = {
    id   = azurerm_resource_group.my_example_rg.id
    name = azurerm_resource_group.my_example_rg.name
  }
}
