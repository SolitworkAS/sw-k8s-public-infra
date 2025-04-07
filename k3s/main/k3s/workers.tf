### Additional Nodes for K3S

locals {
  # Reference the same data source and resource as the outputs in main.tf
  # This explicitly tells Terraform to wait for these before proceeding.
  k3s_token_val      = trimspace(data.local_file.k3s_token_file.content)
  k3s_server_url_val = "https://${azurerm_public_ip.public_ip.ip_address}:6443"
}

# Create 4 nodes (2 master, 2 worker)
resource "azurerm_public_ip" "node_public_ips" {
  count               = 4
  name                = "sw-node-public-ip-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"

  depends_on = [azurerm_virtual_network.virtual_network]
}

# Network Interfaces for nodes
resource "azurerm_network_interface" "node_network_interfaces" {
  count               = 4
  name                = "sw-node-network-interface-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.node_public_ips[count.index].id
  }

  depends_on = [azurerm_virtual_network.virtual_network, azurerm_public_ip.node_public_ips, azurerm_subnet.subnet]
}

# Virtual Machines for nodes
resource "azurerm_linux_virtual_machine" "node_virtual_machines" {
  count               = 4
  name                = "sw-node-vm-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B4ms"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.node_network_interfaces[count.index].id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  depends_on = [
    azurerm_virtual_network.virtual_network, 
    azurerm_public_ip.node_public_ips, 
    azurerm_subnet.subnet, 
    azurerm_network_interface.node_network_interfaces
  ]
}

# Install K3s on additional master nodes (first 2)
resource "azurerm_virtual_machine_extension" "k3s_master_install" {
  count                = 2
  name                 = "k3s-master-install-${count.index + 1}"
  virtual_machine_id   = azurerm_linux_virtual_machine.node_virtual_machines[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  # Use locals instead of variables
  settings = <<SETTINGS
  {
    "commandToExecute": "sudo apt update && sudo apt install -y ufw && sudo curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --server ${local.k3s_server_url_val} --token ${local.k3s_token_val}' sh -s - && sudo ufw allow 6443/tcp && sudo ufw reload"
  }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "commandToExecute": "sudo apt update && sudo apt install -y ufw && sudo curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --server ${local.k3s_server_url_val} --token ${local.k3s_token_val}' sh -s - && sudo ufw allow 6443/tcp && sudo ufw reload"
  }
  PROTECTED_SETTINGS

  depends_on = [
    azurerm_linux_virtual_machine.node_virtual_machines,
    # Implicit dependency on main.tf resources via locals above is now sufficient
  ]
}

# Install K3s on worker nodes (last 2)
resource "azurerm_virtual_machine_extension" "k3s_worker_install" {
  count                = 2
  name                 = "k3s-worker-install-${count.index + 2}"
  virtual_machine_id   = azurerm_linux_virtual_machine.node_virtual_machines[count.index + 2].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  # Use locals instead of variables
  settings = <<SETTINGS
  {
    "commandToExecute": "sudo apt update && sudo apt install -y ufw && sudo curl -sfL https://get.k3s.io | K3S_URL=${local.k3s_server_url_val} K3S_TOKEN=${local.k3s_token_val} sh -s - && sudo ufw allow 6443/tcp && sudo ufw reload"
  }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
    "commandToExecute": "sudo apt update && sudo apt install -y ufw && sudo curl -sfL https://get.k3s.io | K3S_URL=${local.k3s_server_url_val} K3S_TOKEN=${local.k3s_token_val} sh -s - && sudo ufw allow 6443/tcp && sudo ufw reload"
  }
  PROTECTED_SETTINGS

  depends_on = [
    azurerm_linux_virtual_machine.node_virtual_machines,
    # Implicit dependency on main.tf resources via locals above is now sufficient
  ]
}

# Configure KUBECONFIG for all nodes
resource "null_resource" "node_kubeconfig" {
  count = 4
  depends_on = [
    azurerm_linux_virtual_machine.node_virtual_machines,
    azurerm_virtual_machine_extension.k3s_master_install,
    azurerm_virtual_machine_extension.k3s_worker_install
  ]

  provisioner "remote-exec" {
    inline = [
      # Configure KUBECONFIG in shell profiles
      "echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc",
      "echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.profile",
      "source ~/.bashrc",
      "source ~/.profile",

      # Ensure kubeconfig is readable
      "sudo cp /etc/rancher/k3s/k3s.yaml /home/azureuser/kubeconfig.yaml",
      "sudo chown azureuser:azureuser /home/azureuser/kubeconfig.yaml",
      "sudo chmod 600 /home/azureuser/kubeconfig.yaml"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.node_public_ips[count.index].ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }
}

# Install K9s on all nodes
resource "null_resource" "install_k9s_nodes" {
  count = 4
  depends_on = [
    azurerm_linux_virtual_machine.node_virtual_machines,
    azurerm_virtual_machine_extension.k3s_master_install,
    azurerm_virtual_machine_extension.k3s_worker_install
  ]

  provisioner "remote-exec" {
    inline = [
      # Install K9s
      "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml",
      "wget https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.deb",
      "sudo apt install -y ./k9s_linux_amd64.deb",
      "rm k9s_linux_amd64.deb"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.node_public_ips[count.index].ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }
}

# Output the node IPs
output "additional_node_ips" {
  value = azurerm_public_ip.node_public_ips[*].ip_address
  description = "Public IP addresses of the additional nodes"
} 