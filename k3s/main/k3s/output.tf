output "virual_machine_id" {
  value = azurerm_linux_virtual_machine.virtual_machine_master.id
}

output "vm_private_ip" {
  value = azurerm_network_interface.network_interface.ip_configuration[0].private_ip_address
  description = "Private IP address of the VM"
}

output "vat_datamanager_private_ip" {
  value = azurerm_network_interface.network_interface.private_ip_address
  description = "Private IP of the VM running vat_datamanager"
}

output "vm_name" {
  value = azurerm_linux_virtual_machine.virtual_machine_master.name
  description = "Name of the VM"
}

output "vm_public_ip" {
  value = azurerm_public_ip.public_ip.ip_address 
}

output "k3s_server_url" {
  value     = "https://${azurerm_public_ip.public_ip.ip_address}:6443"
  description = "The K3s server URL for joining worker nodes to the cluster"
}

output "debug_values" {
  value = {
    customer = var.customer
    domain = var.domain
    public_ip = azurerm_public_ip.public_ip.ip_address
    container_registry = var.container_registry
    container_username = var.container_registry_username
    container_password = nonsensitive(var.container_registry_password)
    github_client_id = var.github_client_id
    github_client_secret = nonsensitive(var.github_client_secret)
    sso_client_id = var.sso_client_id
    sso_client_secret = nonsensitive(var.sso_client_secret)
    sso_issuer = var.sso_issuer
    microsoft_client_id = var.microsoft_client_id
    microsoft_client_secret = nonsensitive(var.microsoft_client_secret)
    dex_version = var.dex_version
    app_admin_email = var.app_admin_email
    app_admin_first_name = var.app_admin_first_name
    app_admin_last_name = var.app_admin_last_name
    postgres_database = local.postgres_database
    postgres_username = local.postgres_username
    postgres_password = nonsensitive(local.postgres_password)
    bi_dev_role = local.bi_dev_role
    minio_root_user = local.minio_root_user
    minio_root_password = nonsensitive(local.minio_root_password)
  }
  description = "Debug values for troubleshooting"
}



