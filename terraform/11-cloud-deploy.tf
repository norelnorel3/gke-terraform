# Cloud Deploy Delivery Pipeline for Multi-Cluster Deployment
resource "google_clouddeploy_delivery_pipeline" "multi_cluster_app" {
  name        = "multi-cluster-app"
  location    = local.region
  project     = local.project_id
  description = "Pipeline for deploying to multi-cluster GKE environment"

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.config_cluster.name
      profiles  = ["config"]
    }
    stages {
      target_id = google_clouddeploy_target.member_cluster.name
      profiles  = ["member"]
    }
  }

  depends_on = [
    google_project_service.api,
    google_container_cluster.gke,
    google_container_node_pool.general
  ]
}

# Target for Config Cluster (deploys Gateway and HTTPRoute)
resource "google_clouddeploy_target" "config_cluster" {
  name        = "config-cluster"
  location    = local.region
  project     = local.project_id
  description = "Config cluster (${local.clusters[local.config_cluster_key].name}) - deploys Gateway and HTTPRoute"

  gke {
    cluster = "projects/${local.project_id}/locations/${local.clusters[local.config_cluster_key].location}/clusters/${local.clusters[local.config_cluster_key].name}"
  }

  deploy_parameters = {
    "ClusterType" = "config"
  }

  require_approval = false

  depends_on = [
    google_project_service.api,
    google_container_cluster.gke,
    google_container_node_pool.general
  ]
}

# Target for Member Cluster (no Gateway/HTTPRoute)
resource "google_clouddeploy_target" "member_cluster" {
  name        = "member-cluster"
  location    = local.region
  project     = local.project_id
  description = "Member cluster (${local.clusters["cluster2"].name}) - no Gateway/HTTPRoute"

  gke {
    cluster = "projects/${local.project_id}/locations/${local.clusters["cluster2"].location}/clusters/${local.clusters["cluster2"].name}"
  }

  deploy_parameters = {
    "ClusterType" = "member"
  }

  require_approval = false

  depends_on = [
    google_project_service.api,
    google_container_cluster.gke,
    google_container_node_pool.general
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

output "cloud_deploy_config_target" {
  description = "Cloud Deploy config cluster target"
  value       = google_clouddeploy_target.config_cluster.name
}

output "cloud_deploy_member_target" {
  description = "Cloud Deploy member cluster target"
  value       = google_clouddeploy_target.member_cluster.name
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
