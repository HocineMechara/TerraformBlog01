####Terraform Variables

##App Server IP
output "AppServer_IP_Address"{
    value = azurerm_network_interface.TerraformNic01.private_ip_address
}

##SQL Server Name
output "sql_server_name" {
  value = azurerm_mssql_server.sqlserver01.name
}
