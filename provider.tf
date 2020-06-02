# Configure the Microsoft Azure Provider, replace Service Principal and Subscription with your own
provider "azurerm" {
    version = "~>2.1"
	features {}
    
  
	subscription_id = "77a036ca-421e-4694-be23-7589157c28de"
    #client_id       = "6ba5c3dd-879b-4d60-af68-cc279fcb7892"
    #client_secret   = "ObIqdDMMUjJ?IhKHn:43qZ6b6IpOyS[_"
    tenant_id       = "e45cbcc1-1760-419a-a16b-35802285b3b3"
}

