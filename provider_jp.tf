# Configure the Microsoft Azure Provider, replace Service Principal and Subscription with your own
provider "azurerm" {
    version = "=2.21.0"
	features {}
#~>2.1
  
	subscription_id = "77a036ca-421e-4694-be23-7589157c28de"
    tenant_id       = "e45cbcc1-1760-419a-a16b-35802285b3b3"
}

