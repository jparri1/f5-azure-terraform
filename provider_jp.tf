# Configure the Microsoft Azure Provider, replace Service Principal and Subscription with your own
provider "azurerm" {
    version = "=2.21.0"
	features {}
#~>2.1
  
	subscription_id = "7e94cb4c-ad01-4f1e-be16-4acdf28f91f7"
    #client_id       = "6ba5c3dd-879b-4d60-af68-cc279fcb7892"
    #client_secret   = "ObIqdDMMUjJ?IhKHn:43qZ6b6IpOyS[_"
    tenant_id       = "93314589-ec15-4c88-b99f-05a870465a9f"
}

