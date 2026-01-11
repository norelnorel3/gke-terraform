#!/bin/bash

# Bootstrap script to create the GCS bucket for Terraform state
# Run this script BEFORE running terraform init/apply

PROJECT_ID="norel-project-480112"
BUCKET_NAME="${PROJECT_ID}-terraform-state"
REGION="us-central1"

echo "Creating GCS bucket for Terraform state..."

# Enable Storage API
gcloud services enable storage.googleapis.com --project=${PROJECT_ID}

# Create the bucket (if it doesn't exist)
if ! gsutil ls -b gs://${BUCKET_NAME} 2>/dev/null; then
  echo "Creating bucket: ${BUCKET_NAME}"
  gsutil mb -p ${PROJECT_ID} -l ${REGION} gs://${BUCKET_NAME}
  
  # Enable versioning for state file safety
  gsutil versioning set on gs://${BUCKET_NAME}
  
  # Enable object versioning retention
  echo "Bucket created with versioning enabled"
else
  echo "Bucket ${BUCKET_NAME} already exists"
fi

# Set bucket labels
gsutil label ch -l "purpose:terraform-state" gs://${BUCKET_NAME}

echo ""
echo "✅ Terraform state bucket is ready!"
echo "Bucket: gs://${BUCKET_NAME}"
echo ""
echo "You can now run:"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"
