# Cloud Deploy Multi-Cluster Setup

This directory contains the Cloud Deploy configuration for deploying applications to a multi-cluster GKE environment with Gateway API.

## Architecture

- **Config Cluster** (`demo-cluster-1`): Deploys the full application including HTTPRoute
- **Member Cluster** (`demo-cluster-2`): Deploys only the application and ServiceExport (no HTTPRoute)

## How it Works

1. Cloud Deploy pipeline has two targets with different `deployParameters`
2. Each target passes `ClusterType: config` or `ClusterType: member`
3. Skaffold profiles use these parameters to set Helm values
4. The Helm chart conditionally creates HTTPRoute only when `clusterType: config`

## Prerequisites

1. Enable Cloud Deploy API:
```bash
gcloud services enable clouddeploy.googleapis.com --project=norel-project-480112
```

2. Grant Cloud Deploy service account permissions:
```bash
PROJECT_NUMBER=$(gcloud projects describe norel-project-480112 --format="value(projectNumber)")

# Grant Cloud Deploy service account access to deploy to GKE
gcloud projects add-iam-policy-binding norel-project-480112 \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/container.developer"

# Grant Cloud Deploy service account access to act as itself
gcloud iam service-accounts add-iam-policy-binding ${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser" \
    --project=norel-project-480112
```

## Deployment Steps

### 1. Create the Gateway (one-time setup on config cluster)

Before deploying, ensure the Gateway exists on the config cluster:

```bash
kubectl --context=gke_norel-project-480112_us-central1-a_demo-cluster-1 apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: external-http
  namespace: default
spec:
  gatewayClassName: gke-l7-global-external-managed-mc
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      kinds:
      - kind: HTTPRoute
      namespaces:
        from: All
EOF
```

### 2. Register the Cloud Deploy Pipeline

```bash
cd /Users/norelmilihov/personal-exp/cloud-deploy
gcloud deploy apply --file=clouddeploy.yaml --region=us-central1 --project=norel-project-480112
```

### 3. Create a Release

```bash
gcloud deploy releases create release-001 \
    --project=norel-project-480112 \
    --region=us-central1 \
    --delivery-pipeline=multi-cluster-app \
    --source=.
```

### 4. Promote to Member Cluster

After the config cluster deployment succeeds, promote to member cluster:

```bash
gcloud deploy releases promote \
    --release=release-001 \
    --delivery-pipeline=multi-cluster-app \
    --region=us-central1 \
    --project=norel-project-480112
```

## Verify Deployment

### Check deployments on both clusters:
```bash
kubectl --context=gke_norel-project-480112_us-central1-a_demo-cluster-1 get deploy,svc,serviceexport,httproute
kubectl --context=gke_norel-project-480112_us-central1-b_demo-cluster-2 get deploy,svc,serviceexport,httproute
```

### Expected Results:
- **Config cluster**: Should have Deployment, Service, ServiceExport, AND HTTPRoute
- **Member cluster**: Should have Deployment, Service, ServiceExport, but NO HTTPRoute

## File Structure

```
cloud-deploy/
├── clouddeploy.yaml      # Pipeline and target definitions
├── skaffold.yaml         # Skaffold configuration with profiles
├── chart/                # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml       # Default values (no clusterType set)
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── serviceexport.yaml
│       └── httproute.yaml  # Conditional: only when clusterType=config
└── README.md
```

## Key Points

1. **ClusterType is NOT stored in Git** - it's passed via Cloud Deploy `deployParameters`
2. **Same chart, same values.yaml** - both clusters use identical source code
3. **Conditional templating** - HTTPRoute uses `{{- if eq .Values.clusterType "config" }}`
4. **Profiles in Skaffold** - Each target uses a different profile that sets the clusterType

## Troubleshooting

### Check Cloud Deploy pipeline status:
```bash
gcloud deploy delivery-pipelines describe multi-cluster-app \
    --region=us-central1 \
    --project=norel-project-480112
```

### Check release status:
```bash
gcloud deploy releases list \
    --delivery-pipeline=multi-cluster-app \
    --region=us-central1 \
    --project=norel-project-480112
```

### View rollout logs:
```bash
gcloud deploy rollouts list \
    --delivery-pipeline=multi-cluster-app \
    --release=release-001 \
    --region=us-central1 \
    --project=norel-project-480112
```
