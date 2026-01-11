# Cloud Build Trigger for automatic Cloud Deploy releases
# NOTE: You must first connect your GitHub repo to Cloud Build manually:
# https://console.cloud.google.com/cloud-build/triggers/connect?project=norel-project-480112

# Cloud Build trigger - creates Cloud Deploy release on push to main
resource "google_cloudbuild_trigger" "deploy_trigger" {
  name        = "deploy-on-push"
  description = "Trigger Cloud Deploy release when pushing to main branch"
  location    = local.region
  project     = local.project_id

  # GitHub repository connection
  github {
    owner = local.github_owner
    name  = local.github_repo
    push {
      branch = "^main$"
    }
  }

  # Only trigger when cloud-deploy directory changes
  included_files = ["cloud-deploy/**"]

  # Cloud Build configuration (inline)
  build {
    step {
      name = "gcr.io/google.com/cloudsdktool/cloud-sdk"
      entrypoint = "bash"
      args = [
        "-c",
        <<-EOT
          cd cloud-deploy && \
          gcloud deploy releases create release-$SHORT_SHA \
            --project=${local.project_id} \
            --region=${local.region} \
            --delivery-pipeline=${google_clouddeploy_delivery_pipeline.multi_cluster_app.name} \
            --source=.
        EOT
      ]
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  # Service account for Cloud Build
  service_account = google_service_account.cloudbuild.id

  depends_on = [
    google_project_service.api,
    google_clouddeploy_delivery_pipeline.multi_cluster_app
  ]
}

# Service account for Cloud Build
resource "google_service_account" "cloudbuild" {
  account_id   = "cloudbuild-deploy"
  display_name = "Cloud Build Deploy Service Account"
  project      = local.project_id
}

# Grant Cloud Build SA permission to create Cloud Deploy releases
resource "google_project_iam_member" "cloudbuild_deploy_releaser" {
  project = local.project_id
  role    = "roles/clouddeploy.releaser"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Grant Cloud Build SA permission to access Cloud Deploy
resource "google_project_iam_member" "cloudbuild_deploy_viewer" {
  project = local.project_id
  role    = "roles/clouddeploy.viewer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Grant Cloud Build SA permission to write logs
resource "google_project_iam_member" "cloudbuild_logs" {
  project = local.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Grant Cloud Build SA permission to manage storage (for Cloud Deploy artifacts)
resource "google_project_iam_member" "cloudbuild_storage" {
  project = local.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Grant Cloud Build SA permission to act as itself
resource "google_service_account_iam_member" "cloudbuild_sa_user" {
  service_account_id = google_service_account.cloudbuild.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Grant Cloud Build SA permission to act as the Compute service account
# (Cloud Deploy uses this SA to deploy to GKE)
resource "google_service_account_iam_member" "cloudbuild_actas_compute" {
  service_account_id = "projects/${local.project_id}/serviceAccounts/${data.google_project.project.number}-compute@developer.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# Output
output "cloud_build_trigger" {
  description = "Cloud Build trigger name"
  value       = google_cloudbuild_trigger.deploy_trigger.name
}

output "github_connection_url" {
  description = "URL to connect GitHub repo to Cloud Build (do this first!)"
  value       = "https://console.cloud.google.com/cloud-build/triggers/connect?project=${local.project_id}"
}
