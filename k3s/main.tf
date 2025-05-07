module "main" {
  source = "./main"

  is_development = var.is_development

  customer = var.customer

  database_password       = var.database_password

  database_user = var.database_user

  deployment_revision = var.deployment_revision

  container_registry          = var.container_registry
  container_registry_username = var.container_registry_username
  container_registry_password = var.container_registry_password

  app_admin_email            = var.app_admin_email
  app_admin_first_name       = var.app_admin_first_name
  app_admin_last_name        = var.app_admin_last_name

  location         = var.location

  ssh_public_key = var.ssh_public_key
  ssh_private_key = var.ssh_private_key

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

  # Use the provided token if it exists, otherwise use the generated random string.
  k3s_token = var.k3s_token != null ? var.k3s_token : random_string.k3s_token.result
  domain = var.domain
  disk_size_gb = var.disk_size_gb
}

resource "random_string" "k3s_token" {
  length           = 16
  special          = false
  override_special = ""
}