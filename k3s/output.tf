output "k3s_server_url" {
  value     = module.main.k3s_server_url
}

output "vm_public_ip" {
  value     = module.main.vm_public_ip
}

output "k3s_token" {
  description = "The k3s token used for joining nodes."
  value       = random_string.k3s_token.result
}

