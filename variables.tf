# REST API Setting
variable "rest_do_uri" {
  default = "/mgmt/shared/declarative-onboarding"
}

variable "do_data" {
  default = "{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/tmp/f5-declarative-onboarding-1.12.0-1.noarch.rpm\"}"
}

variable "as3_data" {
  default = "{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/tmp/f5-appsvcs-3.18.0-4.noarch.rpm\"}"
}


variable "rest_as3_uri" {
  default = "/mgmt/shared/appsvcs/declare"
}

variable "f5_do_rpm_filename" {
        default = "f5-declarative-onboarding-1.11.1-1.noarch"
}
variable "do_install_dir" {
        default = "/var/tmp/"
}

variable "rest_do_method" {
  default = "POST"
}

variable "rest_as3_method" {
  default = "POST"
}

variable "rest_vm01_do_file" {
  default = "vm01_do_data.json"
}

variable "rest_vm02_do_file" {
  default = "vm02_do_data.json"
}

variable "rest_vm_as3_file" {
  default = "vm_as3_data.json"
}

# Azure Environment
variable "SP" {
  type = map(string)
  default = {
    subscription_id = "77a036ca-421e-4694-be23-7589157c28de"
    client_id       = "6ba5c3dd-879b-4d60-af68-cc279fcb7892"
    client_secret   = "ObIqdDMMUjJ?IhKHn:43qZ6b6IpOyS[_"
    tenant_id       = "e45cbcc1-1760-419a-a16b-35802285b3b3"
  }
}

variable "prefix" {
  default = "f5lab"
}

variable "uname" {
  default = "azureuser"
}

variable "upassword" {
  default = "7h@n05!"
}

variable "location" {
  default = "westus"
}

variable "region" {
  default = "West US"
}

# NETWORK
variable "cidr" {
  default = "10.216.4.0/22"
}

variable "subnets" {
  type = map(string)
  default = {
    "subnet1" = "10.216.6.0/24"
  
  }
}

variable "f5vm01mgmt" {
  default = "10.216.8.5"
}

variable "f5vm01mgmt_sec" {
  default = "10.216.8.6"
}

variable "azlbip" {
  default = "10.216.8.7"
}

variable "f5vm01ext" {
  default = "10.216.8.8"
}

variable "f5vm01ext_sec" {
  default = "10.216.8.9"
}

variable "f5vm02mgmt" {
  default = "10.216.8.10"
}

variable "f5vm02mgmt_sec" {
  default = "10.216.8.11"
}

variable "f5vm02ext" {
  default = "10.216.8.12"
}

variable "f5vm02ext_sec" {
  default = "10.216.8.13"
}
variable "f5vm03mgmt" {
  default = "10.90.1.100"
}

variable "f5vm03ext" {
  default = "10.90.2.100"
}

variable "f5vm03ext_sec" {
  default = "10.90.2.13"
}



variable "backendvm01ext" {
  default = "10.216.8.19"
}

variable "backend02ext" {
  default = "10.216.8.15"
}

variable "jb01" {
  default = "10.216.8.16"
}

variable "backendvm02" {
  default = "10.216.8.17"
}

variable "nginxplus" {
  default = "10.216.8.17"
}

variable "atower" {
  default = "10.216.8.18"
}

variable "advwaf" {
  default = "10.216.8.17"
}


# BIGIP Image
variable "instance_type" {
  default = "Standard_DS2_v2"
}

variable "image_name" {
  default = "f5-bigip-virtual-edition-25m-best-hourly"
  #default = "f5-big-all-1slot-byol"
}

variable "product" {
  default = "f5-big-ip-best"
  #default = "f5-big-ip-byol"
}

variable "bigip_version" {
  default = "latest"
}

# BIGIP Setup
variable "license1" {
  default = "CFMDS-QYEEO-WTQNE-SNJDT-UTUKQUM"
}

variable "license2" {
  default = "WHCOV-MLTIL-PEEGSRZ"
}

variable "host1_name" {
  default = "f5vm01"
}

variable "host2_name" {
  default = "f5vm02"
}

variable "dns_server" {
  default = "8.8.8.8"
}

variable "ntp_server" {
  default = "0.us.pool.ntp.org"
}

variable "timezone" {
  default = "US/Central"
}

## Please check and update the latest DO URL from https://github.com/F5Networks/f5-declarative-onboarding/releases
variable "DO_onboard_URL" {
  default = "https://github.com/F5Networks/f5-declarative-onboarding/releases/download/v1.12.0/f5-declarative-onboarding-1.12.0-1.noarch.rpm"
}

## Please check and update the latest AS3 URL from https://github.com/F5Networks/f5-appsvcs-extension/releases/latest 
variable "AS3_URL" {
  default = "https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.18.0/f5-appsvcs-3.18.0-4.noarch.rpm"
}

variable "ts_url" {
  default = "https://github.com/F5Networks/f5-telemetry-streaming/releases/download/v1.11.0/f5-telemetry-1.11.0-1.noarch.rpm"
}

variable "libs_dir" {
  default = "/config/cloud/azure/node_modules"
}

variable "onboard_log" {
  default = "/var/log/startup-script.log"
}

# TAGS
variable "purpose" {
  default = "public"
}

variable "environment" { #ex. dev/staging/prod
  default = "f5env"
}

variable "owner" {
  default = "f5owner"
}

variable "group" {
  default = "f5group"
}

variable "costcenter" {
  default = "f5costcenter"
}

variable "application" {
  default = "f5app"
}

variable "publickeyfile" {
    description = "public key for server builds"
    default = "jp_pub.key"
}
variable "privatekeyfile" {
    description = "private key for server access"
    default = "jp_private.key.ppk"
}

