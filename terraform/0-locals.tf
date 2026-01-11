locals {
  project_id = "norel-project-480112"
  region     = "us-central1"
  apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "logging.googleapis.com",
    "secretmanager.googleapis.com",
    "gkehub.googleapis.com",
    "mesh.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage.googleapis.com",
    "multiclusterservicediscovery.googleapis.com",
    "multiclusteringress.googleapis.com",
    "trafficdirector.googleapis.com",
    "dns.googleapis.com",
    "clouddeploy.googleapis.com",
    "cloudbuild.googleapis.com"
  ]

  # GitHub repository configuration
  github_owner = "norelnorel3"
  github_repo  = "gke-terraform"

  # Config cluster for multi-cluster gateway (first cluster will be the config cluster)
  config_cluster_key = "cluster1"

  state_bucket_name = "${local.project_id}-terraform-state"

  clusters = {
    cluster1 = {
      name     = "demo-cluster-1"
      location = "us-central1-a"
    }
    cluster2 = {
      name     = "demo-cluster-2"
      location = "us-central1-b"
    }
  }

  # Cloud Deploy targets map - used for creating target resources
  # clusterType is derived from the key: "config" -> "config", anything else -> "member"
  deploy_targets = {
    config = {
      cluster_key = "cluster1"
      profile     = "config"
    }
    member = {
      cluster_key = "cluster2"
      profile     = "member"
    }
  }

  # Ordered list for pipeline stages - ORDER MATTERS for serial pipeline
  # Config cluster must deploy first (Gateway/HTTPRoute), then member clusters
  deploy_stages = [
    {
      key     = "config"
      profile = "config"
    },
    {
      key     = "member"
      profile = "member"
    }
  ]
}
