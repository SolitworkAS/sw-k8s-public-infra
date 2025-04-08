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



