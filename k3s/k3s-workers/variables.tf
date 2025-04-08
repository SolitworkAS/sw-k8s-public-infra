variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "k3s_token" {
  description = "K3s token for node registration"
  type        = string
  sensitive   = true
}

variable "k3s_server_url" {
  description = "URL of the K3s server"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "ssh_private_key" {
  description = "SSH private key for VM access"
  type        = string
  sensitive   = true
}

variable "subnet_id" {
  description = "ID of the subnet where nodes will be placed"
  type        = string
}

variable "virtual_network_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "node_count" {
  description = "Number of nodes to create (total, including masters and workers)"
  type        = number
  default     = 4
}

variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 2
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Size of the virtual machines"
  type        = string
  default     = "Standard_B4ms"
}

variable "admin_username" {
  description = "Admin username for the VMs"
  type        = string
  default     = "azureuser"
} 