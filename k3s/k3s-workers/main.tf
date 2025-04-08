# Create public IPs for nodes
resource "azurerm_public_ip" "node_public_ips" {
  count               = var.node_count
  name                = "sw-node-public-ip-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
}

# Network Interfaces for nodes
resource "azurerm_network_interface" "node_network_interfaces" {
  count               = var.node_count
  name                = "sw-node-network-interface-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.node_public_ips[count.index].id
  }
}

# Virtual Machines for nodes
resource "azurerm_linux_virtual_machine" "node_virtual_machines" {
  count               = var.node_count
  name                = "sw-node-vm-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.node_network_interfaces[count.index].id]
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
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
}

# Install K3s on additional master nodes
resource "azurerm_virtual_machine_extension" "k3s_master_install" {
  count                = var.master_count
  name                 = "k3s-master-install-${count.index + 1}"
  virtual_machine_id   = azurerm_linux_virtual_machine.node_virtual_machines[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
  {
    "commandToExecute": "sudo apt update && sudo apt install -y ufw && sudo curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --server ${var.k3s_server_url} --token ${var.k3s_token}' sh -s - && sudo ufw allow 6443/tcp && sudo ufw allow 2379/tcp && sudo ufw allow 2380/tcp && sudo ufw reload"
  }
  SETTINGS
}

# Install K3s on worker nodes
resource "azurerm_virtual_machine_extension" "k3s_worker_install" {
  count                = var.worker_count
  name                 = "k3s-worker-install-${count.index + var.master_count + 1}"
  virtual_machine_id   = azurerm_linux_virtual_machine.node_virtual_machines[count.index + var.master_count].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
  {
    "commandToExecute": "sudo apt update && sudo apt install -y ufw && sudo curl -sfL https://get.k3s.io | K3S_URL=${var.k3s_server_url} K3S_TOKEN=${var.k3s_token} sh -s - && sudo ufw allow 6443/tcp && sudo ufw reload"
  }
  SETTINGS
}

# Configure KUBECONFIG for all nodes
resource "null_resource" "node_kubeconfig" {
  count = var.node_count
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
      "sudo cp /etc/rancher/k3s/k3s.yaml /home/${var.admin_username}/kubeconfig.yaml",
      "sudo chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/kubeconfig.yaml",
      "sudo chmod 600 /home/${var.admin_username}/kubeconfig.yaml"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.node_public_ips[count.index].ip_address
      user        = var.admin_username
      private_key = var.ssh_private_key
    }
  }
}

# Install K9s on all nodes
resource "null_resource" "install_k9s_nodes" {
  count = var.node_count
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
      user        = var.admin_username
      private_key = var.ssh_private_key
    }
  }
} 