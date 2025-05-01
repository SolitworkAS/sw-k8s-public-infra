### VM's for K3S

locals {
  storage = var.storage_account_name == "" ? "${var.customer}swstorage" : var.storage_account_name

  prefix = var.self_hosted ? var.customer : "shared"

  # Postgres credentials
  postgres_database = "u${random_string.postgres_database.result}"
  postgres_username = "u${random_string.postgres_username.result}"
  postgres_password = "u${random_password.postgres_password.result}"
  bi_dev_role      = "u${random_string.bi_dev_role.result}"

  # Minio credentials
  minio_root_user     = random_string.minio_root_user.result
  minio_root_password = random_password.minio_password.result
}

resource "random_password" "argoworkflows" {
  length  = 16
  special = false
}

resource "random_password" "accesskey" {
  length  = 16
  special = false
}

resource "random_password" "secretkey" {
  length  = 32
  special = false
}

resource "random_password" "postgres_password" {
  length  = 16
  special = false
}

resource "random_password" "minio_password" {
  length  = 16
  special = false
}

resource "random_string" "postgres_database" {
  length  = 8
  special = false
  upper   = false
}

resource "random_string" "postgres_username" {
  length  = 8
  special = false
  upper   = false
}

resource "random_string" "bi_dev_role" {
  length  = 8
  special = false
  upper   = false
}

resource "random_string" "minio_root_user" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg" {
  name                        = var.resource_group_name
  location                    = var.location
  tags = {
    "Managed_By" = "Terraform-Cloud"
  }
}

# Virtual network
resource "azurerm_virtual_network" "virtual_network" {
  name                = "sw-virtual-network"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name

  depends_on = [azurerm_resource_group.rg]
}

# network security group
resource "azurerm_network_security_group" "network_security_group" {
  name                = "sw-network-security-group"
  location            = var.location
  resource_group_name = var.resource_group_name
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule{
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-K3S-API"
    priority                   = 1003 # Priority after SSH and HTTP
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "VirtualNetwork" # Allow traffic from within the VNet
    destination_address_prefix = "*" 
  }

  depends_on = [azurerm_resource_group.rg]
}

resource "azurerm_subnet_network_security_group_association" "subnet_network_security_group_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.network_security_group.id

  depends_on = [azurerm_subnet.subnet, azurerm_network_security_group.network_security_group]
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefixes     = ["10.0.2.0/24"]

  depends_on = [azurerm_virtual_network.virtual_network]
}

# Public IP
resource "azurerm_public_ip" "public_ip" {
  name                = "sw-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"

  depends_on = [azurerm_virtual_network.virtual_network]
}

# Network Interface
resource "azurerm_network_interface" "network_interface" {
  name                = "sw-network-interface"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }

  depends_on = [azurerm_virtual_network.virtual_network, azurerm_public_ip.public_ip, azurerm_subnet.subnet]
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "virtual_machine_master" {
  name                = "sw-virtual-machine-master"
  location            = var.location
  resource_group_name = var.resource_group_name
  size             = "Standard_B4ms"
  admin_username = "azureuser"
  network_interface_ids = [azurerm_network_interface.network_interface.id]
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

  depends_on = [azurerm_virtual_network.virtual_network, azurerm_public_ip.public_ip, azurerm_subnet.subnet, azurerm_network_interface.network_interface]

}

# Recovery Services Vault for VM backups
resource "azurerm_recovery_services_vault" "vm_backup_vault" {
  name                = "${local.prefix}-vm-backup-vault"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard" # Or "RS0" for premium features
  soft_delete_enabled = true       # Recommended for data protection

  tags = {
    "Managed_By" = "Terraform-Cloud"
  }
}

# Backup Policy for the VM
resource "azurerm_backup_policy_vm" "vm_backup_policy" {
  name                = "${local.prefix}-vm-backup-policy"
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_backup_vault.name

  timezone = "UTC" # Adjust if needed

  backup {
    frequency = "Daily"
    time      = "23:00" # Backup time in UTC
  }

  retention_daily {
    count = 7 # Retain daily backups for 7 days
  }
}

# Associate VM with Backup Policy
resource "azurerm_backup_protected_vm" "vm_backup_association" {
  resource_group_name = azurerm_resource_group.rg.name
  recovery_vault_name = azurerm_recovery_services_vault.vm_backup_vault.name
  source_vm_id        = azurerm_linux_virtual_machine.virtual_machine_master.id
  backup_policy_id    = azurerm_backup_policy_vm.vm_backup_policy.id

  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine_master,
    azurerm_backup_policy_vm.vm_backup_policy
  ]
}

resource "azurerm_virtual_machine_extension" "k3s_install" {
  name                 = "k3s-install"
  virtual_machine_id   = azurerm_linux_virtual_machine.virtual_machine_master.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
  {
    "commandToExecute": "sudo apt update && sudo apt install -y ufw && sudo curl -sfL https://get.k3s.io | K3S_TOKEN=${var.k3s_token} sh -s - server --cluster-init --write-kubeconfig-mode 644 && sudo ufw allow 6443/tcp && sudo ufw allow 2379/tcp && sudo ufw allow 2380/tcp && sudo ufw reload"
  }
  SETTINGS
}

resource "null_resource" "k3s_hardening" {
  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine_master,
    azurerm_virtual_machine_extension.k3s_install,
  ]

  provisioner "remote-exec" {
    inline = [
      # Ensure K3s service is stopped before applying config
      "sudo systemctl stop k3s || true",

      # Kernel sysctl
      "echo 'vm.panic_on_oom=0\nvm.overcommit_memory=1\nkernel.panic=10\nkernel.panic_on_oops=1' | sudo tee /etc/sysctl.d/90-kubelet.conf > /dev/null",
      "sudo sysctl -p /etc/sysctl.d/90-kubelet.conf",

      # PSA config
      "sudo cp ${path.module}/security/psa.yaml /var/lib/rancher/k3s/server/psa.yaml",

      # Audit policy config
      "sudo tee /var/lib/rancher/k3s/server/audit.yaml > /dev/null <<EOF\napiVersion: audit.k8s.io/v1\nkind: Policy\nrules:\n  - level: Metadata\nEOF",

      # K3s main config (apply last)
      "sudo cp ${path.module}/security/config.yaml /etc/rancher/k3s/config.yaml",

      # Reload daemon, wait, and start K3s
      "sudo systemctl daemon-reload",
      "sleep 5",
      "sudo systemctl start k3s"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }
}

resource "null_resource" "install_helm" {
  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine_master,
    azurerm_virtual_machine_extension.k3s_install,
    null_resource.k3s_hardening
  ]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for k3s to be fully reset and ready...'",
      "sleep 60",
      "curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash",
      "helm version",
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }
}

resource "null_resource" "install_argocd" {
  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine_master,
    azurerm_virtual_machine_extension.k3s_install,
    null_resource.install_helm
  ]

  provisioner "remote-exec" {
    inline = [
      "kubectl create namespace argocd || true",
      "helm repo add argo https://argoproj.github.io/argo-helm",
      "helm repo update",
      "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml",
      "helm upgrade --install argocd argo/argo-cd --namespace argocd",
      "sleep 60"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }
}

resource "null_resource" "install_k9s" {
  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine_master,
    azurerm_virtual_machine_extension.k3s_install,
    null_resource.install_helm
  ]

  provisioner "remote-exec" {
    inline = [
      # Install K9s
      "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml",
      "wget https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_linux_amd64.deb",
      "sudo apt install -y ./k9s_linux_amd64.deb",
      "rm k9s_linux_amd64.deb",
      
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
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      scp -i ${var.ssh_private_key} azureuser@${azurerm_public_ip.public_ip.ip_address}:/home/azureuser/kubeconfig.yaml ./kubeconfig.yaml
      sed -i "s/127.0.0.1/${azurerm_public_ip.public_ip.ip_address}/g" ./kubeconfig.yaml
      echo "Kubeconfig downloaded to ./kubeconfig.yaml. Use it with:"
      echo "export KUBECONFIG=./kubeconfig.yaml"
    EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "null_resource" "helm_login" {
  depends_on = [
    azurerm_linux_virtual_machine.virtual_machine_master,
    azurerm_virtual_machine_extension.k3s_install,
    null_resource.install_helm
  ]

  provisioner "remote-exec" {
    inline = [
      # Install K9s
      "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml",
      "helm registry login ${var.container_registry} -u ${var.container_registry_username} -p ${var.container_registry_password}", 
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      scp -i ${var.ssh_private_key} azureuser@${azurerm_public_ip.public_ip.ip_address}:/home/azureuser/kubeconfig.yaml ./kubeconfig.yaml
      sed -i "s/127.0.0.1/${azurerm_public_ip.public_ip.ip_address}/g" ./kubeconfig.yaml
      echo "Kubeconfig downloaded to ./kubeconfig.yaml. Use it with:"
      echo "export KUBECONFIG=./kubeconfig.yaml"
    EOT
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "null_resource" "argocd_public_chart_repository" {
  depends_on = [null_resource.install_argocd]

  provisioner "remote-exec" {
    inline = [
      "cat <<EOF > /tmp/argocd-repository-secret.yaml",
      "apiVersion: v1",
      "kind: Secret",
      "metadata:",
      "  name: sw-public-chart",
      "  namespace: argocd",
      "  labels:",
      "    argocd.argoproj.io/secret-type: repository",
      "stringData:",
      "  url: https://github.com/SolitworkAS/sw-k8s-public-infra.git",
      "  project: default",
      "  insecure: \"true\"",  # Ignore TLS validity if needed
      "EOF",

      # Apply the ArgoCD Secret configuration
      "kubectl apply -f /tmp/argocd-repository-secret.yaml -n argocd"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "null_resource" "private_chart_repository_secret" {
  depends_on = [null_resource.install_argocd]

  provisioner "remote-exec" {
    inline = [
      "cat <<EOF > /tmp/argocd-private-secret.yaml",
      "apiVersion: v1",
      "kind: Secret",
      "metadata:",
      "  name: sw-private-chart",
      "  namespace: argocd",
      "  labels:",
      "    argocd.argoproj.io/secret-type: repository",
      "stringData:",
      "  url: \"${var.container_registry}/charts\"", # Private Helm repo URL
      "  name: \"sw-private-chart\"", # Reference name for the repository
      "  type: \"helm\"",  # Set repository type
      "  enableOCI: \"true\"",  # Enable OCI support
      "  username: \"${var.container_registry_username}\"",
      "  password: \"${var.container_registry_password}\"",
      "  project: \"default\"",
      "EOF",

      # Apply the ArgoCD Secret configuration
      "kubectl apply -f /tmp/argocd-private-secret.yaml -n argocd"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "null_resource" "customer_chart_repository_secret" {
  depends_on = [null_resource.install_argocd]

  provisioner "remote-exec" {
    inline = [
      "cat <<EOF > /tmp/argocd-private-secret.yaml",
      "apiVersion: v1",
      "kind: Secret",
      "metadata:",
      "  name: customer-chart",
      "  namespace: argocd",
      "  labels:",
      "    argocd.argoproj.io/secret-type: repository",
      "stringData:",
      "  url: \"${var.container_registry}/charts\"", # Private Helm repo URL
      "  name: \"customer-chart\"", # Reference name for the repository
      "  type: \"helm\"",  # Set repository type
      "  enableOCI: \"true\"",  # Enable OCI support
      "  username: \"${var.container_registry_username}\"",
      "  password: \"${var.container_registry_password}\"",
      "  project: \"default\"",
      "EOF",

      # Apply the ArgoCD Secret configuration
      "kubectl apply -f /tmp/argocd-private-secret.yaml -n argocd"
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "null_resource" "deploy_argocd_application" {
  depends_on = [
    null_resource.install_argocd, null_resource.argocd_public_chart_repository, null_resource.private_chart_repository_secret, null_resource.customer_chart_repository_secret   ]

  provisioner "remote-exec" {
    inline = [
      "cat <<EOF > /tmp/argocd-app.yaml",
      "apiVersion: argoproj.io/v1alpha1",
      "kind: Application",
      "metadata:",
      "  name: initial-${var.customer}-app",
      "  namespace: argocd",
      "spec:",
      "  project: default",
      "  source:",
      "    repoURL: \"https://github.com/SolitworkAS/sw-k8s-public-infra\"",
      "    targetRevision: \"HEAD\"",
      "    path: \"sw-public-chart\"",
      "    helm:",
      "      values: |",
      "        global:",
      "          selfhosted: \"${var.customer}\"",
      "          domain: \"${var.domain}\"",
      "          publicIp: \"${azurerm_public_ip.public_ip.ip_address}\"",
      "          container:",
      "            registry: \"${var.container_registry}\"",
      "            username: \"${var.container_registry_username}\"",
      "            password: \"${var.container_registry_password}\"",
      "            imagePullSecret: \"registry-secret\"",
      "        sw-private-chart:",
      "          environment-chart:",
      "            dex:",
      "              connectors:",
      "                github:",
      "                  clientID: \"${var.github_client_id}\"",
      "                  clientSecret: \"${var.github_client_secret}\"",
      "                solitwork:",
      "                  clientID: \"${var.sso_client_id}\"",
      "                  clientSecret: \"${var.sso_client_secret}\"",
      "                  issuer: \"${var.sso_issuer}\"",
      "                microsoft:",
      "                  clientID: \"${var.microsoft_client_id}\"",
      "                  clientSecret: \"${var.microsoft_client_secret}\"",
      "              version: \"${var.dex_version}\"",
      "            namespace: \"environment\"",
      "            domain: \"${var.domain}\"",
      "            minio:",
      "              bucket:",
      "                name: \"argo-workflows\"",
      "            argo-workflows:",
      "              namespaceOverride: \"argo\"",
      "              server:",
      "                service:",
      "                  type: NodePort",
      "          customer-chart:",
      "            namespace: \"${var.customer}\"",
      "            appAdmin:",
      "              email: \"${var.app_admin_email}\"",
      "              firstName: \"${var.app_admin_first_name}\"",
      "              lastName: \"${var.app_admin_last_name}\"",
      "            postgres:",
      "              database: \"${local.postgres_database}\"",
      "              username: \"${local.postgres_username}\"",
      "              password: \"${local.postgres_password}\"",
      "              biDevRole: \"${local.bi_dev_role}\"",
      "            minio:",
      "              rootUser: \"${local.minio_root_user}\"",
      "              rootPassword: \"${local.minio_root_password}\"",
      "          da-chart:",
      "            namespace: \"da\"",
      "            da:",
      "              da_frontend_image: \"images/da-service/da-frontend\"",
      "              da_service_image: \"images/da-service/da-service\"",
      "  destination:",
      "    server: \"https://kubernetes.default.svc\"",
      "    namespace: \"${var.customer}\"",
      "  syncPolicy:",
      "    automated:",
      "      selfHeal: true",
      "      prune: true",
      "    syncOptions:",
      "    - ServerSideApply=true",
      "EOF",

      # Apply the ArgoCD Application YAML and capture output, forcing conflicts
      "kubectl apply --server-side --force-conflicts -f /tmp/argocd-app.yaml > /tmp/argocd_apply.log 2>&1 || true",
      "echo 'kubectl apply output log:'",
      "cat /tmp/argocd_apply.log",

      # Explicitly trigger an Argo CD refresh
      "echo 'Triggering Argo CD refresh...'",
      "kubectl patch application initial-${var.customer}-app -n argocd -p '{\"metadata\": {\"annotations\": {\"argocd.argoproj.io/refresh\": \"hard\"}}}' --type merge || echo 'Failed to patch Argo CD app for refresh, continuing anyway'"
      
    ]

    connection {
      type        = "ssh"
      host        = azurerm_public_ip.public_ip.ip_address
      user        = "azureuser"
      private_key = var.ssh_private_key
    }
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}