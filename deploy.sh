#!/bin/bash
# deploy.sh — Build images, push to ECR, deploy to EKS
# Run this from the root of your shopsphere/ repo
# Usage: ./deploy.sh

set -e  # Exit immediately if any command fails

# ─── Configuration ────────────────────────────────────────────────────────────
# Get these from: terraform output (run inside infrastructure/)
AWS_ACCOUNT_ID="922806890560"          # e.g. 123456789012
AWS_REGION="ap-south-1"
CLUSTER_NAME="shopsphere-cluster"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_TAG="${1:-latest}"                   # Pass a tag as arg, defaults to 'latest'

# Your folder names (matching your GitHub repo exactly)
declare -A SERVICES
SERVICES["user-services"]="user-services"       # key=ECR repo name, value=local folder
SERVICES["product-service"]="product-service"
SERVICES["order-service"]="order-service"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +%H:%M:%S)] $1${NC}"; }
info() { echo -e "${YELLOW}[$(date +%H:%M:%S)] $1${NC}"; }

# ─── Step 1: Connect kubectl to EKS ──────────────────────────────────────────
log "Connecting kubectl to EKS cluster..."
aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}"

kubectl get nodes
log "kubectl connected ✓"

# ─── Step 2: Authenticate Docker to ECR ──────────────────────────────────────
log "Authenticating Docker to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"
log "ECR login successful ✓"

# ─── Step 3: Build and push each image ───────────────────────────────────────
for ECR_REPO in "${!SERVICES[@]}"; do
  LOCAL_FOLDER="${SERVICES[$ECR_REPO]}"
  FULL_IMAGE="${ECR_REGISTRY}/shopsphere-${ECR_REPO}:${IMAGE_TAG}"

  info "Building ${ECR_REPO} from ./${LOCAL_FOLDER}..."
  docker build \
    --platform linux/amd64 \
    --target runtime \
    -t "${FULL_IMAGE}" \
    "./${LOCAL_FOLDER}"

  info "Pushing ${FULL_IMAGE}..."
  docker push "${FULL_IMAGE}"
  log "${ECR_REPO} pushed ✓"
done

# ─── Step 4: Update image tags in manifests ───────────────────────────────────
log "Patching image tags in k8s manifests..."
for ECR_REPO in "${!SERVICES[@]}"; do
  FULL_IMAGE="${ECR_REGISTRY}/shopsphere-${ECR_REPO}:${IMAGE_TAG}"
  # Replace the YOUR_ACCOUNT_ID placeholder with real values
  sed -i "s|YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/shopsphere-${ECR_REPO}:latest|${FULL_IMAGE}|g" \
    "k8s/base/${ECR_REPO}.yaml"
done

# ─── Step 5: Apply Kubernetes manifests ───────────────────────────────────────
log "Applying Kubernetes manifests..."
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/secret.yaml
kubectl apply -f k8s/base/user-services.yaml
kubectl apply -f k8s/base/product-service.yaml
kubectl apply -f k8s/base/order-service.yaml
kubectl apply -f k8s/base/ingress.yaml
kubectl apply -f k8s/base/hpa.yaml

# ─── Step 6: Wait for rollout ─────────────────────────────────────────────────
log "Waiting for deployments to roll out..."
kubectl rollout status deployment/user-services    -n shopsphere --timeout=120s
kubectl rollout status deployment/product-service -n shopsphere --timeout=120s
kubectl rollout status deployment/order-service   -n shopsphere --timeout=120s

# ─── Step 7: Print status and ALB URL ─────────────────────────────────────────
log "Deployment complete! Current pod status:"
kubectl get pods -n shopsphere

log "Services:"
kubectl get services -n shopsphere

log "Ingress (wait ~3 min for ALB to provision):"
kubectl get ingress -n shopsphere

ALB_URL=$(kubectl get ingress shopsphere-ingress -n shopsphere \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "provisioning...")
echo ""
log "Your public URL: http://${ALB_URL}"
log "Test it: curl http://${ALB_URL}/health"