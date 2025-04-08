output "vm_public_ip" {
    value = module.k3s.vm_public_ip  
}

output "k3s_server_url" {
  value     = module.k3s.k3s_server_url
  description = "The K3s server URL for joining worker nodes to the cluster"
}



