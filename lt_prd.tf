variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

#variable "resource_group" {}
variable "resource_group" {}

# Configure the Azure Resource Manager Provider
provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

# Create a resource group
resource "azurerm_resource_group" "prd" {
    name     = "${var.resource_group}"
    location = "West US"
}

# Create a virtual network in the web_servers resource group
resource "azurerm_virtual_network" "prdNetwork" {
  name                = "prdNetwork"
  address_space       = ["12.0.0.0/16"]
  location            = "West US"
  resource_group_name = "${azurerm_resource_group.prd.name}"
}

resource "azurerm_subnet" "prdpublic" {
    name = "prdpublic"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    virtual_network_name = "${azurerm_virtual_network.prdNetwork.name}"
    address_prefix = "12.0.1.0/24"
    network_security_group_id = "${azurerm_network_security_group.prdwebNSG.id}"
}

resource "azurerm_dns_zone" "prdazure" {
   name = "ad.zencloud.com"
   resource_group_name = "${azurerm_resource_group.prd.name}"
}

resource "azurerm_dns_a_record" "prdazure_a_web_pub" {
   name = "prdweb_pub"
   zone_name = "${azurerm_dns_zone.prdazure.name}"
   resource_group_name = "${azurerm_resource_group.prd.name}"
   ttl = "300"
   records = ["${azurerm_public_ip.prdweb01pub.ip_address}"]
}

resource "azurerm_public_ip" "prdweb01pub" {
    name = "prdweb01pub"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    public_ip_address_allocation = "static"
    domain_name_label = "prdwebpub"
}

resource "azurerm_network_interface" "prdwebpudinter" {
    name = "prdwebpudinter"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_security_group_id = "${azurerm_network_security_group.prdwebNSG.id}"

    ip_configuration {
        name = "prdconfiguration1"
        subnet_id = "${azurerm_subnet.prdpublic.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = "${azurerm_public_ip.prdweb01pub.id}"
    }
}

resource "azurerm_storage_account" "prdswebacnt" {
    name = "prdswebacnt"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    location = "westus"
    account_type = "Standard_LRS"
}

resource "azurerm_storage_container" "prdswebcont" {
    name = "prdswebcont"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    storage_account_name = "${azurerm_storage_account.prdswebacnt.name}"
    container_access_type = "private"
}

resource "azurerm_storage_blob" "prdswebblob" {
    name = "prdswebblob.vhd"

    resource_group_name = "${azurerm_resource_group.prd.name}"
    storage_account_name = "${azurerm_storage_account.prdswebacnt.name}"
    storage_container_name = "${azurerm_storage_container.prdswebcont.name}"
    type = "page"
    size = 5120
}

resource "azurerm_virtual_machine" "prdweb01" {
    name = "prdweb01"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_interface_ids = ["${azurerm_network_interface.prdwebpudinter.id}"]
    vm_size = "Standard_A0"


    storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer = "WindowsServer"
        sku = "2008-R2-SP1"
        version = "latest"
    }

    storage_os_disk {
        name = "myosdisk01"
        vhd_uri = "${azurerm_storage_account.prdswebacnt.primary_blob_endpoint}${azurerm_storage_container.prdswebcont.name}/myosdisk01.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
    }

    os_profile {
        computer_name = "prdweb01"
        admin_username = "zenadmin"
        admin_password = "Redhat#12345"
    }

    os_profile_windows_config {
        provision_vm_agent = true
        enable_automatic_upgrades = false
    }
}

resource "azurerm_network_security_group" "prdwebNSG" {
    name = "prdwebNSG"
    location = "West US"
    resource_group_name = "${azurerm_resource_group.prd.name}"
}

resource "azurerm_network_security_rule" "HTTP" {
    name = "HTTP"
    priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "80"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_security_group_name = "${azurerm_network_security_group.prdwebNSG.name}"
}

resource "azurerm_network_security_rule" "HTTPS" {
    name = "HTTPS"
    priority = 200
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "443"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_security_group_name = "${azurerm_network_security_group.prdwebNSG.name}"
}

resource "azurerm_network_security_rule" "RDP-web" {
    name = "RDP-web"
    priority = 300
        direction = "Inbound"
        access = "Allow"
        protocol = "*"
        source_port_range = "*"
        destination_port_range = "3389"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_security_group_name = "${azurerm_network_security_group.prdwebNSG.name}"
}

resource "azurerm_network_security_rule" "Winrm" {
    name = "Winrm"
    priority = 400
        direction = "Inbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "5985"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_security_group_name = "${azurerm_network_security_group.prdwebNSG.name}"
}

resource "azurerm_network_security_rule" "HTTP-out" {
    name = "HTTP-out"
    priority = 100
        direction = "Outbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "0"
        destination_port_range = "65535"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_security_group_name = "${azurerm_network_security_group.prdwebNSG.name}"
}

resource "azurerm_network_security_rule" "HTTPS-out" {
    name = "HTTPS-out"
    priority = 200
        direction = "Outbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "0"
        destination_port_range = "65535"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_security_group_name = "${azurerm_network_security_group.prdwebNSG.name}"
}

resource "azurerm_network_security_rule" "Winrm-out" {
    name = "Winrm-out"
    priority = 300
        direction = "Outbound"
        access = "Allow"
        protocol = "TCP"
        source_port_range = "*"
        destination_port_range = "5985"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    resource_group_name = "${azurerm_resource_group.prd.name}"
    network_security_group_name = "${azurerm_network_security_group.prdwebNSG.name}"
}

output "Application URLs: " {
        value = "${azurerm_public_ip.prdweb01pub.ip_address}"
}

output "DNS entry" {
        value = "web_pub.ad.zencloud.com"
}
