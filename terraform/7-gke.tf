resource "google_container_cluster" "gke" {
  for_each                 = local.clusters
  name                     = each.value.name
  location                 = each.value.location
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = google_compute_network.vpc.self_link
  subnetwork               = google_compute_subnetwork.private.self_link
  networking_mode          = "VPC_NATIVE"

  deletion_protection = false

  # Increase timeout for cluster creation
  timeouts {
    create = "45m"
    update = "45m"
    delete = "30m"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
    config_connector_config {
      enabled = true
    }
    gke_backup_agent_config {
      enabled = false
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "${local.project_id}.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pods"
    services_secondary_range_name = "k8s-services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = each.key == "cluster1" ? "192.168.0.0/28" : "192.168.1.0/28"
  }

  # Enable Gateway API for multi-cluster gateway
  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  # Note: Fleet registration is handled by google_gke_hub_membership resource in 9-fleet.tf
  # This avoids the 1-minute timeout issue with the inline fleet block

  depends_on = [
    google_project_service.api
  ]
}
