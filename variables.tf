####Terraform Variables

##Environments
variable "env" {
    description = "The particular environment"
    type        = map(string)

    default     = {
        development = "DEV"
        test        = "TST"
        production  = "PRD"
        default     = "DEFAULT"
    }
}

##Vnet addresses
variable "cidr" {
        description = "The network adress for each environment"
        type        = map(string)

        default     = {
            development = "10.1.0.0/16"
            test        = "10.2.0.0/16"
            production  = "10.3.0.0/16"
            default     = "10.0.0.0/16"
        }
}

##Subnet addresses
variable "subnet_cidrs" {
        description = "The network adress for each subnet in each environment"
        type        = map(map(string))

        default     = {
            development = {
                front = "10.1.10.0/24"
                mid   = "10.1.20.0/24"
                back  = "10.1.30.0/24"
                bastion = "10.1.200.0/24"
            },
            test = {
                front = "10.2.10.0/24"
                mid   = "10.2.20.0/24"
                back  = "10.2.30.0/24"
                bastion = "10.2.200.0/24"
            },
            production = {
                front = "10.3.10.0/24"
                mid   = "10.3.20.0/24"
                back  = "10.3.30.0/24"
                bastion = "10.3.200.0/24"
            },
            default = {
                front = "10.0.10.0/24"
                mid   = "10.0.20.0/24"
                back  = "10.0.30.0/24"
                bastion = "10.0.200.0/24"
            }           
        }
}

##SQL server admin password
variable "sqlserver_password" {
  description = "The password for the sql server admin"
  type        = string
  sensitive   = true
}

##Azure sq database properties
variable "database_settings" {
        description = "The database settings for each stage"
        type        = map(map(string))

        default     = {
            sku = {
                production      = "BC_Gen5_4"
                test            = "GP_Gen5_4"
                development     = "GP_Gen5_4"
                default         = "GP_Gen5_4"
            },
           ptr = {
                production      = "30"
                test            = "7"
                development     = "7"
                default         = "7"                
           },
           backupstorag = {
                production      = "GeoZone"
                test            = "Zone"
                development     = "Zone"
                default         = "Zone" 
           }

        }
}

##VM admin password
variable "vm_password" {
  description = "The password for the vm"
  type        = string
  sensitive   = true
}

