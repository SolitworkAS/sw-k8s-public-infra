locals {
  resource_group_name = "${var.customer}-afc-k8s"
}

module "k3s" {
  source = "./k3s"
  ssh_public_key = var.ssh_public_key
  ssh_private_key = var.ssh_private_key
  customer = var.customer
  location = var.location
  resource_group_name = local.resource_group_name
  container_registry          = var.container_registry
  container_registry_username = var.container_registry_username
  container_registry_password = var.container_registry_password
  min_cpu = var.min_cpu
  min_memory = var.min_memory
  storage_account_name = var.storage_account_name
  database_user               = var.database_user
  database_password           = var.database_password
  keycloak_admin_user         = var.keycloak_admin_user
  keycloak_admin_password     = var.keycloak_admin_password
  keycloak_version = var.keycloak_version
  app_admin_email            = var.app_admin_email
  app_admin_first_name       = var.app_admin_first_name
  app_admin_last_name        = var.app_admin_last_name
  app_admin_initial_password = var.app_admin_initial_password
  smtp_from     = var.smtp_from
  smtp_host     = var.smtp_host
  smtp_port     = var.smtp_port
  smtp_username = var.smtp_username
  smtp_password = var.smtp_password
  reportingpassword = var.reportingpassword

  github_client_id = var.github_client_id
  github_client_secret = var.github_client_secret
}
