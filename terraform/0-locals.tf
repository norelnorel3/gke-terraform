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

  # Clusters configuration - includes GKE cluster info and Cloud Deploy settings
  # cluster_type is used for both Cloud Deploy target naming and Skaffold profile selection
  # "config" = deploys Gateway/HTTPRoute + app, "member" = deploys only app
  clusters = {
    cluster1 = {
      name         = "demo-cluster-1"
      location     = "us-central1-a"
      cluster_type = "config"
    }
    cluster2 = {
      name         = "demo-cluster-2"
      location     = "us-central1-b"
      cluster_type = "member"
    }
    cluster3 = {
      name         = "demo-cluster-3"
      location     = "us-central1-b"
      cluster_type = "member"
    }    
    # cluster4 = {
    #   name         = "demo-cluster-4"
    #   location     = "us-central1-a"
    #   cluster_type = "member"
    # }     
  }
}
