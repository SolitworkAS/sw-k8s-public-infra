output "node_public_ips" {
  description = "Public IP addresses of all nodes"
  value       = azurerm_public_ip.node_public_ips[*].ip_address
}

output "master_public_ips" {
  description = "Public IP addresses of master nodes"
  value       = slice(azurerm_public_ip.node_public_ips[*].ip_address, 0, var.master_count)
}

output "worker_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = slice(azurerm_public_ip.node_public_ips[*].ip_address, var.master_count, var.node_count)
}

output "node_vm_ids" {
  description = "IDs of all node VMs"
  value       = azurerm_linux_virtual_machine.node_virtual_machines[*].id
}

output "master_vm_ids" {
  description = "IDs of master node VMs"
  value       = slice(azurerm_linux_virtual_machine.node_virtual_machines[*].id, 0, var.master_count)
}

output "worker_vm_ids" {
  description = "IDs of worker node VMs"
  value       = slice(azurerm_linux_virtual_machine.node_virtual_machines[*].id, var.master_count, var.node_count)
} 