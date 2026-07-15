#!/bin/bash
# install-alb-controller.sh
# Run this ONCE after terraform apply, before deploying services.
# The ALB Controller watches for Ingress objects and creates real AWS ALBs.

set -e

AWS_ACCOUNT_ID="922806890560"    # Replace this
AWS_REGION="ap-south-1"
CLUSTER_NAME="shopsphere-cluster"
VPC_ID="vpc-073055c14ce993302"                # Get from: terraform output (add vpc_id to infrastructure/outputs.tf)

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[$(date +%H:%M:%S)] $1${NC}"; }

# ─── 1. Connect kubectl ───────────────────────────────────────────────────────
log "Connecting to cluster..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

# ─── 2. Install eksctl (if not already installed) ────────────────────────────
if ! command -v eksctl &> /dev/null; then
  log "Installing eksctl..."
  curl --silent --location \
    "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
    | tar xz -C /tmp
  sudo mv /tmp/eksctl /usr/local/bin/
fi

# ─── 3. Install Helm (if not already installed) ──────────────────────────────
if ! command -v helm &> /dev/null; then
  log "Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ─── 4. Download the IAM policy for ALB controller ───────────────────────────
log "Downloading ALB controller IAM policy..."
curl -o /tmp/alb-iam-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json

# ─── 5. Create the IAM policy in AWS ─────────────────────────────────────────
log "Creating IAM policy..."
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file:///tmp/alb-iam-policy.json \
  2>/dev/null || log "Policy already exists, skipping..."

# ─── 6. Create IAM service account (links K8s service account to IAM role) ───
log "Creating IAM service account for ALB controller..."
eksctl create iamserviceaccount \
  --cluster="${CLUSTER_NAME}" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name="AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy" \
  --approve \
  --region="${AWS_REGION}"

# ─── 7. Install ALB controller via Helm ──────────────────────────────────────
log "Adding eks Helm repo..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

log "Installing AWS Load Balancer Controller..."
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${AWS_REGION}" \
  --set vpcId="${VPC_ID}"

# ─── 8. Verify installation ───────────────────────────────────────────────────
log "Waiting for controller to be ready..."
kubectl rollout status deployment/aws-load-balancer-controller \
  -n kube-system --timeout=120s

log "ALB controller installed ✓"
kubectl get deployment -n kube-system aws-load-balancer-controller