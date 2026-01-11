# Post-Deployment Steps for Multi-Cluster Gateway

After running `terraform apply`, complete the following steps to verify and use Multi-Cluster Gateway.

## 1. Connect to Both Clusters

```bash
# Get credentials for cluster 1 (config cluster)
gcloud container clusters get-credentials demo-cluster-1 --zone us-central1-a --project norel-project-480112

# Get credentials for cluster 2
gcloud container clusters get-credentials demo-cluster-2 --zone us-central1-b --project norel-project-480112
```

## 2. Verify Fleet Membership

Check that both clusters are registered in Fleet:

```bash
gcloud container fleet memberships list --project=norel-project-480112
```

Expected output should show both clusters:
```
NAME                        EXTERNAL_ID                            LOCATION
demo-cluster-1-membership   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   us-central1-a
demo-cluster-2-membership   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   us-central1-b
```

## 3. Verify Multi-Cluster Services (MCS)

Check that MCS is enabled:

```bash
gcloud container fleet multi-cluster-services describe --project=norel-project-480112
```

Expected output should show `state: ACTIVE` for both memberships.

## 4. Verify Multi-Cluster Gateway Controller (Fleet Ingress)

```bash
gcloud container fleet ingress describe --project=norel-project-480112
```

Expected output should show:
- `resourceState.state: ACTIVE`
- `state.code: OK`
- Config membership set to `demo-cluster-1-membership`

## 5. Verify GatewayClasses in Config Cluster

Switch to the config cluster (demo-cluster-1) and check GatewayClasses:

```bash
kubectl config use-context gke_norel-project-480112_us-central1-a_demo-cluster-1
kubectl get gatewayclasses
```

Expected output should include multi-cluster GatewayClasses:
```
NAME                                  CONTROLLER                  ACCEPTED   AGE
gke-l7-global-external-managed        networking.gke.io/gateway   True       10m
gke-l7-global-external-managed-mc     networking.gke.io/gateway   True       5m
gke-l7-gxlb                           networking.gke.io/gateway   True       10m
gke-l7-gxlb-mc                        networking.gke.io/gateway   True       5m
gke-l7-regional-external-managed      networking.gke.io/gateway   True       10m
gke-l7-regional-external-managed-mc   networking.gke.io/gateway   True       5m
gke-l7-rilb                           networking.gke.io/gateway   True       10m
gke-l7-rilb-mc                        networking.gke.io/gateway   True       5m
```

The `-mc` suffix indicates multi-cluster GatewayClasses.

## 6. Deploy a Sample Multi-Cluster Gateway

### a. Create a Gateway in the Config Cluster

```bash
kubectl config use-context gke_norel-project-480112_us-central1-a_demo-cluster-1
```

Create `gateway.yaml`:

```yaml
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
```

Apply it:
```bash
kubectl apply -f gateway.yaml
```

### b. Deploy a Sample App to Both Clusters

Create `app.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whereami
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whereami
  template:
    metadata:
      labels:
        app: whereami
    spec:
      containers:
      - name: whereami
        image: us-docker.pkg.dev/google-samples/containers/gke/whereami:v1.2.22
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: whereami
spec:
  selector:
    app: whereami
  ports:
  - port: 8080
    targetPort: 8080
```

Apply to both clusters:
```bash
kubectl --context=gke_norel-project-480112_us-central1-a_demo-cluster-1 apply -f app.yaml
kubectl --context=gke_norel-project-480112_us-central1-b_demo-cluster-2 apply -f app.yaml
```

### c. Export Services for Multi-Cluster

Create `service-export.yaml`:

```yaml
apiVersion: net.gke.io/v1
kind: ServiceExport
metadata:
  name: whereami
  namespace: default
```

Apply to both clusters:
```bash
kubectl --context=gke_norel-project-480112_us-central1-a_demo-cluster-1 apply -f service-export.yaml
kubectl --context=gke_norel-project-480112_us-central1-b_demo-cluster-2 apply -f service-export.yaml
```

### d. Create HTTPRoute in Config Cluster

Create `httproute.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: whereami-route
  namespace: default
spec:
  parentRefs:
  - name: external-http
    namespace: default
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - group: net.gke.io
      kind: ServiceImport
      name: whereami
      port: 8080
```

Apply it:
```bash
kubectl --context=gke_norel-project-480112_us-central1-a_demo-cluster-1 apply -f httproute.yaml
```

### e. Get Gateway IP and Test

```bash
kubectl get gateway external-http -o jsonpath='{.status.addresses[0].value}'
```

Test with curl:
```bash
curl http://<GATEWAY_IP>/
```

## Config Connector Setup (Optional)

If you want to use Config Connector to manage GCP resources from Kubernetes:

### a. Switch to cluster context
```bash
kubectl config use-context gke_norel-project-480112_us-central1-a_demo-cluster-1
```

### b. Create ConfigConnector custom resource

Create `configconnector.yaml`:

```yaml
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  googleServiceAccount: "config-connector-cluster1@norel-project-480112.iam.gserviceaccount.com"
```

Apply it:
```bash
kubectl apply -f configconnector.yaml
```

## Troubleshooting

### GatewayClasses not available

If `-mc` GatewayClasses are not showing up, try disabling and re-enabling Fleet Ingress:

```bash
gcloud container fleet ingress disable --project=norel-project-480112

gcloud container fleet ingress enable \
    --config-membership=projects/norel-project-480112/locations/us-central1-a/memberships/demo-cluster-1-membership \
    --project=norel-project-480112
```

### Check Fleet Feature Status

```bash
gcloud container fleet features list --project=norel-project-480112
```

## Notes

- **Config Cluster**: `demo-cluster-1` is the config cluster where you deploy Gateway and HTTPRoute resources
- **Multi-cluster Services**: Services need to be exported using `ServiceExport` to be available across clusters
- **Gateway Classes**: Use `-mc` suffixed classes for multi-cluster routing (e.g., `gke-l7-global-external-managed-mc`)
- Both clusters are in the same VPC, which is required for multi-cluster gateway

## Cloud Deploy (Automated Deployment)

Terraform creates a Cloud Deploy pipeline with two targets:
- **config-cluster**: Deploys to demo-cluster-1 with `ClusterType=config` (includes Gateway & HTTPRoute)
- **member-cluster**: Deploys to demo-cluster-2 with `ClusterType=member` (no Gateway/HTTPRoute)

### Deploy Your Application

1. Navigate to your Helm chart directory:
```bash
cd /Users/norelmilihov/personal-exp/cloud-deploy
```

2. Create a release:
```bash
gcloud deploy releases create release-$(date +%Y%m%d-%H%M%S) \
    --project=norel-project-480112 \
    --region=us-central1 \
    --delivery-pipeline=multi-cluster-app \
    --source=.
```

3. Monitor the deployment:
```bash
gcloud deploy releases list \
    --delivery-pipeline=multi-cluster-app \
    --region=us-central1 \
    --project=norel-project-480112
```

4. After config-cluster succeeds, promote to member-cluster:
```bash
gcloud deploy releases promote \
    --release=<RELEASE_NAME> \
    --delivery-pipeline=multi-cluster-app \
    --region=us-central1 \
    --project=norel-project-480112
```

### How It Works

The `ClusterType` parameter is passed via Cloud Deploy's `deployParameters` (defined in Terraform), not stored in Git. The Helm chart conditionally deploys resources based on this parameter:

| Resource | Config Cluster | Member Cluster |
|----------|----------------|----------------|
| Deployment | ✅ | ✅ |
| Service | ✅ | ✅ |
| ServiceExport | ✅ | ✅ |
| Gateway | ✅ | ❌ |
| HTTPRoute | ✅ | ❌ |

## Reference

- [Prepare environment for multi-cluster Gateways](https://cloud.google.com/kubernetes-engine/docs/how-to/prepare-environment-multi-cluster-gateways)
- [Deploy external multi-cluster Gateways](https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-multi-cluster-gateways)
- [Cloud Deploy documentation](https://cloud.google.com/deploy/docs)