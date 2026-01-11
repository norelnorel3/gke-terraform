# Get project data for project number
data "google_project" "project" {
  project_id = local.project_id
}

# Fleet membership for both clusters
resource "google_gke_hub_membership" "cluster_membership" {
  for_each      = local.clusters
  membership_id = "${each.value.name}-membership"
  
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.gke[each.key].id}"
    }
  }
  authority {
    issuer = "https://container.googleapis.com/v1/${google_container_cluster.gke[each.key].id}"
  }

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }

  depends_on = [
    google_container_cluster.gke,
    google_container_node_pool.general,
    google_project_service.api
  ]
}

# Enable Multi-cluster Service Discovery feature (MCS)
# https://cloud.google.com/kubernetes-engine/docs/how-to/prepare-environment-multi-cluster-gateways#enable_multi-cluster_services_in_the_fleet
resource "google_gke_hub_feature" "multiclusterservicediscovery" {
  name     = "multiclusterservicediscovery"
  location = "global"
  project  = local.project_id

  depends_on = [
    google_project_service.api,
    google_gke_hub_membership.cluster_membership
  ]
}

# Enable the multi-cluster Gateway controller (Fleet Ingress)
# https://cloud.google.com/kubernetes-engine/docs/how-to/prepare-environment-multi-cluster-gateways#enable_the_multi-cluster_gateway_controller
resource "google_gke_hub_feature" "multiclusteringress" {
  name     = "multiclusteringress"
  location = "global"
  project  = local.project_id

  spec {
    multiclusteringress {
      config_membership = google_gke_hub_membership.cluster_membership[local.config_cluster_key].id
    }
  }

  depends_on = [
    google_project_service.api,
    google_gke_hub_membership.cluster_membership,
    google_gke_hub_feature.multiclusterservicediscovery
  ]
}

# IAM permissions for the multi-cluster Gateway controller service account
# https://cloud.google.com/kubernetes-engine/docs/how-to/prepare-environment-multi-cluster-gateways#enable_the_multi-cluster_gateway_controller
resource "google_project_iam_member" "multicluster_ingress_controller" {
  project = local.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-multiclusteringress.iam.gserviceaccount.com"

  depends_on = [
    google_gke_hub_feature.multiclusteringress
  ]
}

# Grant network viewer role for multi-cluster gateway controller
resource "google_project_iam_member" "multicluster_network_viewer" {
  project = local.project_id
  role    = "roles/compute.networkViewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-multiclusteringress.iam.gserviceaccount.com"

  depends_on = [
    google_gke_hub_feature.multiclusteringress
  ]
}
