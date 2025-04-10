# K3s Workers Module

This Terraform module creates additional nodes (both master and worker) for a K3s cluster in Azure.

## Features

- Creates multiple nodes (both master and worker) for a K3s cluster
- Configures the nodes to join an existing K3s cluster
- Installs K9s on all nodes for easier cluster management
- Configures KUBECONFIG on all nodes
- Allows flexible configuration of master and worker node counts

## Usage

```hcl
module "k3s_workers" {
  source = "./k3s-workers"

  # Required variables
  location            = "northeurope"
  resource_group_name = "my-resource-group"
  k3s_token           = "your-k3s-token"
  k3s_server_url      = "https://your-k3s-server:6443"
  ssh_public_key      = "your-ssh-public-key"
  ssh_private_key     = "your-ssh-private-key"
  subnet_id           = "your-subnet-id"
  virtual_network_id  = "your-virtual-network-id"
  
  # Optional variables with defaults
  master_count   = 2  # Number of master nodes to create
  worker_count   = 2  # Number of worker nodes to create
  node_count     = 4  # Total number of nodes (must equal master_count + worker_count)
  vm_size        = "Standard_B4ms"
  admin_username = "azureuser"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location | Azure region where resources will be created | string | n/a | yes |
| resource_group_name | Name of the resource group | string | n/a | yes |
| k3s_token | K3s token for node registration | string | n/a | yes |
| k3s_server_url | URL of the K3s server | string | n/a | yes |
| ssh_public_key | SSH public key for VM access | string | n/a | yes |
| ssh_private_key | SSH private key for VM access | string | n/a | yes |
| subnet_id | ID of the subnet where nodes will be placed | string | n/a | yes |
| virtual_network_id | ID of the virtual network | string | n/a | yes |
| master_count | Number of master nodes to create | number | 2 | no |
| worker_count | Number of worker nodes to create | number | 2 | no |
| node_count | Total number of nodes (must equal master_count + worker_count) | number | 4 | no |
| vm_size | Size of the virtual machines | string | "Standard_B4ms" | no |
| admin_username | Admin username for the VMs | string | "azureuser" | no |

## Outputs

| Name | Description |
|------|-------------|
| node_public_ips | Public IP addresses of all nodes |
| master_public_ips | Public IP addresses of master nodes |
| worker_public_ips | Public IP addresses of worker nodes |
| node_vm_ids | IDs of all node VMs |
| master_vm_ids | IDs of master node VMs |
| worker_vm_ids | IDs of worker node VMs | 