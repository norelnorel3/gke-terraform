# Config Connector configuration
# Note: Config Connector addon is enabled in the cluster configuration.
# After cluster creation, you'll need to:
# 1. Install Config Connector CRDs and controller (if not auto-installed)
# 2. Create ConfigConnector custom resource in each cluster
# 3. Set up Workload Identity bindings for Config Connector service accounts

# Service account for Config Connector (one per cluster)
resource "google_service_account" "config_connector" {
  for_each     = local.clusters
  account_id   = "config-connector-${each.key}"
  display_name = "Config Connector Service Account for ${each.value.name}"
}

# IAM bindings for Config Connector service accounts
# Config Connector typically needs editor or owner role to manage GCP resources
resource "google_project_iam_member" "config_connector_editor" {
  for_each = local.clusters
  project  = local.project_id
  role     = "roles/editor"
  member   = "serviceAccount:${google_service_account.config_connector[each.key].email}"
}
