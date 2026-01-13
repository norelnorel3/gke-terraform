# Custom Target Type for GKE with Helm
# This allows deploy_parameters to be available as CLOUD_DEPLOY_* env vars
resource "google_clouddeploy_custom_target_type" "gke_helm" {
  name        = "gke-helm-target"
  location    = local.region
  project     = local.project_id
  description = "Custom target type for GKE with Helm - exposes deploy_parameters as env vars"

  custom_actions {
    render_action = "render-helm"
    deploy_action = "deploy-gke"
  }

  depends_on = [
    google_project_service.api
  ]
}

# Cloud Deploy Targets - using custom target type
resource "google_clouddeploy_target" "cluster" {
  for_each = local.clusters

  name        = each.key  # cluster1, cluster2, cluster3, etc.
  location    = local.region
  project     = local.project_id
  description = "${title(each.value.cluster_type)} cluster (${each.value.name})"

  # Use custom target instead of GKE target
  custom_target {
    custom_target_type = google_clouddeploy_custom_target_type.gke_helm.id
  }

  # These parameters become env vars in custom actions
  deploy_parameters = {
    "ClusterType"      = each.value.cluster_type
    "profile"          = each.value.cluster_type  # Same as ClusterType - used for Skaffold profile
    "cluster_name"     = each.value.name
    "cluster_location" = each.value.location
    "project"          = local.project_id
  }

  require_approval = false

  depends_on = [
    google_project_service.api,
    google_container_cluster.gke,
    google_container_node_pool.general,
    google_clouddeploy_custom_target_type.gke_helm
  ]
}

# Multi-target that groups all cluster targets for parallel deployment
resource "google_clouddeploy_target" "multi_cluster" {
  name        = "multi-cluster"
  location    = local.region
  project     = local.project_id
  description = "Multi-target for parallel deployment to all clusters"

  multi_target {
    target_ids = [for k, v in google_clouddeploy_target.cluster : v.name]
  }

  require_approval = false

  depends_on = [
    google_clouddeploy_target.cluster
  ]
}

# Cloud Deploy Delivery Pipeline for Multi-Cluster Deployment
resource "google_clouddeploy_delivery_pipeline" "multi_cluster_app" {
  name        = "multi-cluster-app"
  location    = local.region
  project     = local.project_id
  description = "Pipeline for deploying to multi-cluster GKE environment"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.multi_cluster.name
      # No profiles needed - each child target uses its own deploy_parameters
    }
  }

  depends_on = [
    google_project_service.api,
    google_container_cluster.gke,
    google_container_node_pool.general,
    google_clouddeploy_target.cluster,
    google_clouddeploy_target.multi_cluster
  ]
}

# IAM: Grant Cloud Deploy service account permission to deploy to GKE
resource "google_project_iam_member" "clouddeploy_container_developer" {
  project = local.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_project_service.api
  ]
}

# IAM: Grant Cloud Deploy service account permission to write logs
resource "google_project_iam_member" "clouddeploy_logs" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_project_service.api
  ]
}

# IAM: Grant Cloud Deploy service account permission to access storage (for artifacts)
resource "google_project_iam_member" "clouddeploy_storage" {
  project = local.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_project_service.api
  ]
}

# IAM: Grant Cloud Deploy service account to act as itself
resource "google_service_account_iam_member" "clouddeploy_service_account_user" {
  service_account_id = "projects/${local.project_id}/serviceAccounts/${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_project_service.api
  ]
}

# Output the pipeline name for easy reference
output "cloud_deploy_pipeline" {
  description = "Cloud Deploy pipeline name"
  value       = google_clouddeploy_delivery_pipeline.multi_cluster_app.name
}

output "cloud_deploy_targets" {
  description = "Cloud Deploy child targets"
  value       = { for k, v in google_clouddeploy_target.cluster : k => v.name }
}

output "cloud_deploy_multi_target" {
  description = "Cloud Deploy multi-target (deploys to all clusters in parallel)"
  value       = google_clouddeploy_target.multi_cluster.name
}

output "cloud_deploy_create_release_command" {
  description = "Command to create a Cloud Deploy release"
  value       = <<-EOT
    # Navigate to your Helm chart directory and run:
    gcloud deploy releases create release-$(date +%Y%m%d-%H%M%S) \
      --project=${local.project_id} \
      --region=${local.region} \
      --delivery-pipeline=${google_clouddeploy_delivery_pipeline.multi_cluster_app.name} \
      --source=.
  EOT
}
