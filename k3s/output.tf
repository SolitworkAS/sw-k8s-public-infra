output "k3s_server_url" {
  value     = "https://${azurerm_public_ip.public_ip.ip_address}:6443"
  description = "The K3s server URL for joining worker nodes to the cluster"
}

output "vm_public_ip" {
  value     = module.main.vm_public_ip
}

