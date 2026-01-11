# GKE Terraform Deployment

This Terraform configuration deploys two GKE clusters with Fleet, Config Connector, and Multi-cluster Gateway support.

## Prerequisites

1. Google Cloud SDK installed and configured
2. Terraform >= 1.0 installed
3. Appropriate GCP permissions to create resources
4. Project ID: `norel-project-480112`

## Initial Setup

### 1. Create Terraform State Bucket

Before running Terraform, you need to create the GCS bucket for storing Terraform state:

```bash
./bootstrap-state-bucket.sh
```

Or manually:

```bash
PROJECT_ID="norel-project-480112"
BUCKET_NAME="${PROJECT_ID}-terraform-state"
REGION="us-central1"

# Enable Storage API
gcloud services enable storage.googleapis.com --project=${PROJECT_ID}

# Create bucket
gsutil mb -p ${PROJECT_ID} -l ${REGION} gs://${BUCKET_NAME}

# Enable versioning
gsutil versioning set on gs://${BUCKET_NAME}
```

### 2. Initialize Terraform

```bash
terraform init
```

This will:
- Download required providers
- Configure the GCS backend for state storage

### 3. Plan and Apply

```bash
# Review the changes
terraform plan

# Apply the configuration
terraform apply
```

## State Management

Terraform state is stored in GCS bucket: `norel-project-480112-terraform-state`

- **Location**: `gs://norel-project-480112-terraform-state/gke-terraform/terraform.tfstate`
- **Versioning**: Enabled for state file safety
- **Backend**: GCS backend configured in `1-providers.tf`

## What Gets Deployed

- **VPC Network**: Regional VPC with public and private subnets
- **NAT Gateway**: For private subnet internet access
- **Two GKE Clusters**:
  - `demo-cluster-1` in `us-central1-a`
  - `demo-cluster-2` in `us-central1-b`
- **Fleet Membership**: Both clusters registered with GKE Hub
- **Config Connector**: Enabled on both clusters
- **Gateway API**: Enabled for multi-cluster gateway
- **Node Pools**: Auto-scaling node pools for each cluster

## Post-Deployment

See [POST_DEPLOYMENT.md](./POST_DEPLOYMENT.md) for steps to:
- Configure Config Connector
- Set up Multi-cluster Gateway
- Test cross-cluster routing

## State Backend Configuration

The Terraform state is stored remotely in GCS. The backend configuration is in `1-providers.tf`:

```hcl
backend "gcs" {
  bucket = "norel-project-480112-terraform-state"
  prefix = "gke-terraform/terraform.tfstate"
}
```

## Troubleshooting

### State Lock Issues

If Terraform operations are stuck due to state locks:

```bash
# List locks (if using state locking)
gsutil ls gs://norel-project-480112-terraform-state/gke-terraform/terraform.tfstate*

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Migrating from Local State

If you have an existing local state file and want to migrate to GCS:

```bash
# After creating the bucket and configuring backend
terraform init -migrate-state
```

This will prompt you to migrate the existing state to the GCS backend.
