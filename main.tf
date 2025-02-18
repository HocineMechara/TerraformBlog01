####Ressources provisioned with Terraform

# Creating a Resource Group
resource "azurerm_resource_group" "TerraformRG" {
  name     = "RG_${var.env[terraform.workspace]}"
  location = "Switzerland North"
}

##Network

# Creating a VNet
resource "azurerm_virtual_network" "TerraformVNET" {
  name                = "VNET_${var.env[terraform.workspace]}"
  address_space       = [var.cidr[terraform.workspace]]
  location            = azurerm_resource_group.TerraformRG.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
}

# Creating the front tier subnet
resource "azurerm_subnet" "TerraformSubnetFrontTier" {
  name                 = "FRONT_SUBNET_${var.env[terraform.workspace]}"
  resource_group_name  = azurerm_resource_group.TerraformRG.name
  virtual_network_name = azurerm_virtual_network.TerraformVNET.name
  address_prefixes     = [var.subnet_cidrs[terraform.workspace]["front"]]
}

# Creating the mid tier subnet
resource "azurerm_subnet" "TerraformSubnetMidTier" {
  name                 = "MID_SUBNET_${var.env[terraform.workspace]}"
  resource_group_name  = azurerm_resource_group.TerraformRG.name
  virtual_network_name = azurerm_virtual_network.TerraformVNET.name
  address_prefixes     = [var.subnet_cidrs[terraform.workspace]["mid"]]
}

# Creating the back tier subnet
resource "azurerm_subnet" "TerraformSubnetBackTier" {
  name                 = "BACK_SUBNET_${var.env[terraform.workspace]}"
  resource_group_name  = azurerm_resource_group.TerraformRG.name
  virtual_network_name = azurerm_virtual_network.TerraformVNET.name
  address_prefixes     = [var.subnet_cidrs[terraform.workspace]["back"]]
  private_endpoint_network_policies = "Enabled"
}

# Creating the bastion subnet
resource "azurerm_subnet" "TerraformSubnetBastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.TerraformRG.name
  virtual_network_name = azurerm_virtual_network.TerraformVNET.name
  address_prefixes     = [var.subnet_cidrs[terraform.workspace]["bastion"]]
}

##Azure SQL 

# creating an azure sql server
resource "azurerm_mssql_server" "sqlserver01" {
  name                         = "sqlserver01-${lower(var.env[terraform.workspace])}"
  resource_group_name          = azurerm_resource_group.TerraformRG.name
  location                     = azurerm_resource_group.TerraformRG.location
  administrator_login          = "sqladmin"
  administrator_login_password = var.sqlserver_password
  version                      = "12.0"
  public_network_access_enabled =  "false"
}

# creating an azure sql database
resource "azurerm_mssql_database" "sqldatabase001" {
  name                  = "sqldb01-${lower(var.env[terraform.workspace])}"
  server_id             = azurerm_mssql_server.sqlserver01.id
  sku_name              = var.database_settings["sku"][terraform.workspace]
  storage_account_type  = var.database_settings["backupstorag"][terraform.workspace]

  short_term_retention_policy {
    retention_days    = var.database_settings["ptr"][terraform.workspace]
  }
}

## DNS

# Creating a private DNS zone
resource "azurerm_private_dns_zone" "TerraformDNSZone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.TerraformRG.name
}

# Creating a virtual network link
resource "azurerm_private_dns_zone_virtual_network_link" "TerraformVnetLink" {
  name                  = "vnet-link"
  resource_group_name   = azurerm_resource_group.TerraformRG.name
  private_dns_zone_name = azurerm_private_dns_zone.TerraformDNSZone.name
  virtual_network_id    = azurerm_virtual_network.TerraformVNET.id
}

# creating an azure private endpoint for sql server
resource "azurerm_private_endpoint" "sqlserver01_endpoint" {
  name                = "${azurerm_mssql_server.sqlserver01.name}-endpoint"
  location            = azurerm_resource_group.TerraformRG.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
  subnet_id           = azurerm_subnet.TerraformSubnetBackTier.id

  private_service_connection {
    name                           = "${azurerm_mssql_server.sqlserver01.name}-private-serviceconnection"
    private_connection_resource_id = azurerm_mssql_server.sqlserver01.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

    private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.TerraformDNSZone.id]
  }
}

##Bastion 

##Creating a public IP for the bastion
resource "azurerm_public_ip" "TerraformBastionIP" {
  name                = "BastionIP_${var.env[terraform.workspace]}"
  location            = azurerm_resource_group.TerraformRG.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

##Creating a bastion
resource "azurerm_bastion_host" "TerraformBastion" {
  sku                 = "Standard"
  name                = "Bastion_${var.env[terraform.workspace]}"
  location            = azurerm_resource_group.TerraformRG.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
  copy_paste_enabled  = "true"
  tunneling_enabled   = "true"

  ip_configuration {
    name                 = "Bastion_${var.env[terraform.workspace]}_IP_configuration1"
    subnet_id            = azurerm_subnet.TerraformSubnetBastion.id
    public_ip_address_id = azurerm_public_ip.TerraformBastionIP.id
  }
}

##App Server

##Creating a network interface for app server
resource "azurerm_network_interface" "TerraformNic01" {
  name                = "nic_win_01_${var.env[terraform.workspace]}"
  location            = azurerm_resource_group.TerraformRG.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
  ip_configuration {
    name                          = "nic_win_01_${var.env[terraform.workspace]}IP_configuration"
    subnet_id                     = azurerm_subnet.TerraformSubnetMidTier.id
    private_ip_address_allocation = "Dynamic"
  }
}

##Creating App Server
resource "azurerm_windows_virtual_machine" "TerraformVM01" {
  name                = "vm-win-01-${var.env[terraform.workspace]}"
  resource_group_name = azurerm_resource_group.TerraformRG.name
  location            = azurerm_resource_group.TerraformRG.location
  size                = "Standard_DS2_v2"
  admin_username      = "vmadmin"
  admin_password      = var.vm_password
  network_interface_ids = [
    azurerm_network_interface.TerraformNic01.id
  ]

  os_disk {
    name                 = "disk-os-win-01"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

####Network security groups

##Creating a network security group for the front tier subnet
resource "azurerm_network_security_group" "TerraformNSGFront" {
  name                = "Front_NSG_${var.env[terraform.workspace]}"
  location            = azurerm_resource_group.TerraformRG.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
}

resource "azurerm_subnet_network_security_group_association" "TerraformNSGFrontAssociation" {
subnet_id                 = azurerm_subnet.TerraformSubnetFrontTier.id
network_security_group_id = azurerm_network_security_group.TerraformNSGFront.id
}

##Creating a network security group for the mid tier subnet
resource "azurerm_network_security_group" "TerraformNSGMid" {
  name                = "Mid_NSG_${var.env[terraform.workspace]}"
  location            = azurerm_resource_group.TerraformRG.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
}

resource "azurerm_subnet_network_security_group_association" "TerraformNSGMidAssociation" {
subnet_id                 = azurerm_subnet.TerraformSubnetMidTier.id
network_security_group_id = azurerm_network_security_group.TerraformNSGMid.id
}

##Creating a network security group for the back tier subnet
resource "azurerm_network_security_group" "TerraformNSGBack" {
  name                = "Back_NSG_${var.env[terraform.workspace]}"
  location            = azurerm_resource_group.TerraformRG.location
  resource_group_name = azurerm_resource_group.TerraformRG.name
}

resource "azurerm_subnet_network_security_group_association" "TerraformNSGBackAssociation" {
subnet_id                 = azurerm_subnet.TerraformSubnetBackTier.id
network_security_group_id = azurerm_network_security_group.TerraformNSGBack.id
}

##Creating network security group rules for the front tier subnet
resource "azurerm_network_security_rule" "FrontTierRule1" {
  name                        = "BlockAllInbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.TerraformRG.name
  network_security_group_name = azurerm_network_security_group.TerraformNSGFront.name
}

resource "azurerm_network_security_rule" "FrontTierRule2" {
  name                        = "Allow-HTTPS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.TerraformRG.name
  network_security_group_name = azurerm_network_security_group.TerraformNSGFront.name
}

##Creating network security group rules for the mid tier subnet
resource "azurerm_network_security_rule" "MidTierRule1" {
  name                        = "BlockAllInbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.TerraformRG.name
  network_security_group_name = azurerm_network_security_group.TerraformNSGMid.name
}

resource "azurerm_network_security_rule" "MidTierRule2" {
  name                        = "Allow-HTTP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = azurerm_subnet.TerraformSubnetFrontTier.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.TerraformRG.name
  network_security_group_name = azurerm_network_security_group.TerraformNSGMid.name
}

resource "azurerm_network_security_rule" "MidTierRule3" {
  name                        = "Allow-RDP"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = azurerm_subnet.TerraformSubnetBastion.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.TerraformRG.name
  network_security_group_name = azurerm_network_security_group.TerraformNSGMid.name
}

##Creating network security group rules for the back tier subnet
resource "azurerm_network_security_rule" "TerraformSubnetBackTierTierRule1" {
  name                        = "BlockAllInbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.TerraformRG.name
  network_security_group_name = azurerm_network_security_group.TerraformNSGBack.name
}

resource "azurerm_network_security_rule" "TerraformSubnetBackTierTierRule2" {
  name                        = "Allow-SQL"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = azurerm_subnet.TerraformSubnetMidTier.address_prefixes[0]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.TerraformRG.name
  network_security_group_name = azurerm_network_security_group.TerraformNSGBack.name
}

resource "azurerm_network_security_rule" "TerraformSubnetBackTierTierRule3" {
  name                        = "Block-Internet"
  priority                    = 101
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.TerraformRG.name
  network_security_group_name = azurerm_network_security_group.TerraformNSGBack.name
}