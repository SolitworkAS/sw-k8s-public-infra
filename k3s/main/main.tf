locals {
  resource_group_name = "${var.customer}-afc-k8s"
}

module "k3s" {
  source = "./k3s"
  is_development = var.is_development
  ssh_public_key = var.ssh_public_key
  ssh_private_key = var.ssh_private_key
  customer = var.customer
  deployment_revision = var.deployment_revision
  deploy_da_app = var.deploy_da_app
  deploy_fc_app = var.deploy_fc_app
  location = var.location
  resource_group_name = local.resource_group_name
  container_registry          = var.container_registry
  container_registry_username = var.container_registry_username
  container_registry_password = var.container_registry_password
  database_user               = var.database_user
  database_password           = var.database_password
  app_admin_email            = var.app_admin_email
  app_admin_first_name       = var.app_admin_first_name
  app_admin_last_name        = var.app_admin_last_name

  github_client_id = var.github_client_id
  github_client_secret = var.github_client_secret

  sso_client_id = var.sso_client_id
  sso_client_secret = var.sso_client_secret
  sso_issuer = var.sso_issuer

  microsoft_client_id = var.microsoft_client_id
  microsoft_client_secret = var.microsoft_client_secret

  intuit_client_id = var.intuit_client_id
  intuit_client_secret = var.intuit_client_secret
  intuit_redirect_uri = var.intuit_redirect_uri

  encryption_key = var.encryption_key

  k3s_token = var.k3s_token
  domain = var.domain
  disk_size_gb = var.disk_size_gb
}
