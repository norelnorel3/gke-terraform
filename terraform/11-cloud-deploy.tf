# Cloud Deploy Targets - using for_each loop
resource "google_clouddeploy_target" "cluster" {
  for_each = local.deploy_targets

  name        = "${each.key}-cluster"
  location    = local.region
  project     = local.project_id
  description = "${title(each.key)} cluster (${local.clusters[each.value.cluster_key].name})"

  gke {
    cluster = "projects/${local.project_id}/locations/${local.clusters[each.value.cluster_key].location}/clusters/${local.clusters[each.value.cluster_key].name}"
  }

  deploy_parameters = {
    "ClusterType" = each.key == "config" ? "config" : "member"
  }

  require_approval = false

  depends_on = [
    google_project_service.api,
    google_container_cluster.gke,
    google_container_node_pool.general
  ]
}

# Cloud Deploy Delivery Pipeline for Multi-Cluster Deployment
resource "google_clouddeploy_delivery_pipeline" "multi_cluster_app" {
  name        = "multi-cluster-app"
  location    = local.region
  project     = local.project_id
  description = "Pipeline for deploying to multi-cluster GKE environment"

  serial_pipeline {
    # Dynamic stages - order is defined in local.deploy_stages list
    dynamic "stages" {
      for_each = local.deploy_stages
      content {
        target_id = google_clouddeploy_target.cluster[stages.value.key].name
        profiles  = [stages.value.profile]
      }
    }
  }

  depends_on = [
    google_project_service.api,
    google_container_cluster.gke,
    google_container_node_pool.general,
    google_clouddeploy_target.cluster
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
  description = "Cloud Deploy targets"
  value       = { for k, v in google_clouddeploy_target.cluster : k => v.name }
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
