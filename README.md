# DevSecOps Lab

A production-grade DevSecOps reference implementation on AWS — built from scratch to demonstrate security hardening at every layer: infrastructure, CI/CD pipeline, container supply chain, and Kubernetes runtime.

The lab assumes an empty AWS account and provisions everything via Terraform, from VPC to EKS, with a GitHub Actions pipeline that enforces security gates before any image reaches a registry or cluster.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GitHub Actions                               │
│                                                                     │
│  Push to web-server/                                                │
│       │                                                             │
│       ▼                                                             │
│  ┌─────────────────────┐                                            │
│  │ container-security  │  ← tfsec on *.tf changes                  │
│  │                     │                                            │
│  │ 1. Base image check │ ← fetch allowlist from S3 (KMS-encrypted) │
│  │    (SHA256 pinning)  │                                            │
│  │ 2. Dockerfile lint  │ ← hadolint                                 │
│  └──────────┬──────────┘                                            │
│             │ (pass)                                                │
│             ▼                                                       │
│  ┌─────────────────────┐                                            │
│  │  build-scan-push    │                                            │
│  │                     │                                            │
│  │ 1. Build image      │ ← multi-stage, distroless runtime          │
│  │ 2. Trivy scan       │ ← blocks on CRITICAL/HIGH CVEs             │
│  │ 3. Push to ECR      │ ← only on main, immutable tags, KMS        │
│  └──────────┬──────────┘                                            │
│             │ (main branch only)                                    │
│             ▼                                                       │
│  ┌─────────────────────┐                                            │
│  │  sign-and-attest    │                                            │
│  │                     │                                            │
│  │ 1. Cosign sign      │ ← keyless OIDC, stored in ECR              │
│  │ 2. Generate SBOM    │ ← Syft, SPDX JSON                          │
│  │ 3. Attest SBOM      │ ← Cosign attestation in registry           │
│  └─────────────────────┘                                            │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS Infrastructure                          │
│                                                                     │
│  eu-north-1                                                         │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  VPC (10.0.0.0/16)                                          │   │
│  │                                                             │   │
│  │  ┌──────────────────┐    ┌──────────────────┐              │   │
│  │  │  Public Subnets  │    │  Private Subnets  │             │   │
│  │  │  (IGW routing)   │    │  (NAT routing)    │             │   │
│  │  └────────┬─────────┘    └────────┬──────────┘             │   │
│  │           │ (NAT GW)              │                         │   │
│  │           └──────────────────────┘                         │   │
│  │                        │                                   │   │
│  │              ┌──────────▼──────────┐                       │   │
│  │              │   EKS Cluster 1.32  │                       │   │
│  │              │                     │                       │   │
│  │              │  ┌───────────────┐  │                       │   │
│  │              │  │  Node Group   │  │ ← IMDSv2, KMS EBS     │   │
│  │              │  │  (t3.medium)  │  │                       │   │
│  │              │  └───────────────┘  │                       │   │
│  │              │                     │                       │   │
│  │              │  ┌───────────────┐  │                       │   │
│  │              │  │    Kyverno    │  │ ← admission control   │   │
│  │              │  │   Policies    │  │                       │   │
│  │              │  └───────────────┘  │                       │   │
│  │              └─────────────────────┘                       │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  Supporting services:                                               │
│  ┌───────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────┐  │
│  │    ECR    │  │     KMS     │  │  S3 Allowlist │  │CloudWatch│  │
│  │ (images)  │  │ (encryption)│  │  (base images)│  │  (logs)  │  │
│  └───────────┘  └─────────────┘  └──────────────┘  └──────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Lab Phases

### Phase 1 — Foundation: VPC
Network infrastructure across 2 availability zones.

- VPC `10.0.0.0/16` in `eu-north-1`
- Public subnets with Internet Gateway routing
- Private subnets with NAT Gateway routing
- Kubernetes-aware subnet tags for ELB and cluster discovery
- Remote state in versioned, encrypted S3

### Phase 2 — Secure Modules
Reusable Terraform modules with security defaults baked in.

**`modules/secure-s3`**
- KMS encryption at rest (not SSE-S3)
- TLS enforcement — denies HTTP requests and TLS < 1.2
- Public access fully blocked
- Versioning + 90-day non-current version expiry
- S3 server access logging enabled

**`modules/secure-ec2`**
- No SSH — SSM-only access via IAM role
- IMDSv2 enforced (blocks SSRF metadata endpoint abuse)
- KMS-encrypted gp3 EBS root volume
- No public IP assignment
- Deny-all inbound security group by default

### Phase 3 — Security Layer: OIDC, IAM, KMS, Allowlist
Identity and secrets infrastructure that everything else depends on.

- **GitHub OIDC provider** — GitHub Actions assumes an AWS role without static credentials
- **GitHub pipeline IAM role** — scoped to ECR push/pull for `devsecops-lab` repo, allowlist bucket read, and KMS decrypt
- **KMS key** (`alias/security-allowlists`) — encrypts allowlist bucket, rotation enabled, 30-day deletion window
- **Security allowlist S3 bucket** — KMS-encrypted, versioned, stores approved container base images

### Phase 4 — Container Runtime: ECR
Private container registry with supply-chain guardrails.

- Image tag immutability — prevents tag reassignment attacks
- Scan on push enabled
- KMS encryption at rest
- Auto-expiry of untagged images after 7 days
- Account-restricted repository policy

### Phase 5 — Container Platform: EKS
Managed Kubernetes cluster provisioned entirely via Terraform.

| Property | Value |
|---|---|
| Version | 1.32 |
| Node location | Private subnets only |
| Instance type | t3.medium |
| Scaling | Min 1 / Desired 2 / Max 3 |
| Metadata service | IMDSv2 enforced |
| Node disk | 50 GB gp3, KMS encrypted |
| Secret encryption | KMS (Secrets API resource) |
| Control plane logs | API, audit, authenticator, controllerManager, scheduler — 30-day retention |
| Addons | VPC-CNI, kube-proxy, CoreDNS, EBS CSI driver |
| IRSA | EBS CSI driver with dedicated service account role |

### Phase 6 — Kubernetes Admission Control: Kyverno
Four enforced cluster policies that block non-compliant pods at admission time.

| Policy | Action | Rule |
|---|---|---|
| `restrict-image-registries` | ENFORCE | Only images from the project ECR registry are permitted |
| `verify-image-signatures` | ENFORCE | Images must carry a valid Cosign signature from the GitHub Actions workflow |
| `verify-sbom-attestation` | ENFORCE | Images must have a Cosign-signed SPDX SBOM attestation |
| `pod-security-baseline` | ENFORCE | No privileged containers, no host namespaces, no hostPath volumes, non-root user, all capabilities dropped, CPU/memory limits required |

Kyverno failure policy is set to `IGNORE` for dev (prevents cluster lockout). Change to `FAIL` for production.

---

## Container Build Security Pipeline

Security is applied before the image is built, not after.

```
Push on web-server/
         │
         ▼
┌────────────────────────────────────────────────────────┐
│  Stage 1: Pre-Build Security (container-security.yml)  │
│                                                        │
│  • AWS OIDC auth (no static credentials)               │
│  • Fetch base image allowlist from S3 (KMS-encrypted)  │
│  • check-base-image.py validates every FROM line:      │
│    - extracts full image reference incl. SHA256 digest │
│    - checks against allowlist JSON                     │
│    - exits 1 if any image not approved                 │
│  • hadolint Dockerfile linting                         │
└───────────────────┬────────────────────────────────────┘
                    │ (pass)
                    ▼
┌────────────────────────────────────────────────────────┐
│  Stage 2: Build, Scan, Push (build-scan-push)          │
│                                                        │
│  • Build: no-cache, tagged with git SHA                │
│  • Trivy scan (local image, pre-push):                 │
│    - blocks on CRITICAL or HIGH CVEs                   │
│    - ignores unfixed vulnerabilities                   │
│  • Push to ECR (main branch only)                      │
│    - immutable tag: $REGISTRY/devsecops-lab:$SHA       │
│    - outputs image digest URI                          │
└───────────────────┬────────────────────────────────────┘
                    │ (main branch only)
                    ▼
┌────────────────────────────────────────────────────────┐
│  Stage 3: Sign & Attest (sign-and-attest)              │
│                                                        │
│  • Cosign keyless sign via GitHub OIDC:                │
│    - identity: github.com/rafftoubol/DevSecOpsLab      │
│    - signature stored as OCI artifact in ECR           │
│    - logged to Sigstore Rekor transparency log         │
│  • SBOM generation (Syft, SPDX JSON format)            │
│  • Cosign SBOM attestation stored in ECR               │
└────────────────────────────────────────────────────────┘
```

### Base Image Allowlist

Approved images are stored in `security-objects/docker-base-image-allowlist.json` and synced to the KMS-encrypted S3 allowlist bucket. Every image is pinned to an exact SHA256 digest.

Currently approved:

| Image | Stage | Why |
|---|---|---|
| `ghcr.io/astral-sh/uv:python3.12-bookworm-slim@sha256:...` | Build | uv Python package manager |
| `cgr.dev/chainguard/python@sha256:...` | Runtime | Distroless Python — no shell, no package manager |

### Application Container

Multi-stage Dockerfile:

- **Builder stage**: uv installs locked dependencies (`uv sync --frozen --no-dev`), no dev packages in final image
- **Runtime stage**: Chainguard distroless Python — minimal attack surface, no shell, no unnecessary utilities, non-root enforced by image design
- FastAPI app serving on port 8000 (`/`, `/health`, `/info`)

---

## Security Patterns Applied

| Pattern | Implementation |
|---|---|
| Shift-left | Base image validation and Dockerfile linting run before build |
| Immutable artifacts | ECR tag immutability + SHA256-pinned base images |
| Keyless signing | Cosign + GitHub OIDC — no long-lived signing keys |
| Supply chain provenance | Cosign signatures + SBOM attestations verified at deploy time by Kyverno |
| No static credentials | GitHub OIDC → AWS role assumption throughout pipeline |
| Encryption everywhere | KMS for EKS secrets, EBS, ECR, S3; TLS 1.2+ enforced for all S3 access |
| Least privilege | IRSA for pod-level IAM, IMDSv2 on nodes, deny-all inbound security groups |
| Audit trail | CloudWatch control plane logs, S3 access logs, ECR scan on push, Rekor transparency log |
| Distroless runtime | No shell in production container — limits post-exploitation blast radius |

---

## IaC Security Scanning

`tfsec.yml` triggers on any `*.tf` file change and runs `aquasecurity/tfsec-action` against the entire repository, blocking the PR on misconfiguration findings.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure as Code | Terraform (AWS, Helm, kubectl providers) |
| Cloud | AWS — VPC, EKS, ECR, KMS, S3, IAM, CloudWatch |
| CI/CD | GitHub Actions with OIDC federation |
| Container scanning | Trivy |
| IaC scanning | tfsec |
| Dockerfile linting | hadolint |
| Image signing | Cosign (keyless, Sigstore) |
| SBOM generation | Syft (Anchore) |
| Admission control | Kyverno |
| Container runtime | Kubernetes 1.32 on EKS |
| Package management | uv (Python) |
| Application framework | FastAPI + uvicorn |

---

## Setup & Replication

### Prerequisites

- AWS account (clean/empty state recommended)
- AWS CLI configured (`aws configure`)
- Terraform >= 1.6
- kubectl + Helm (used by Terraform providers)

### Step 1 — Bootstrap Terraform State Bucket

This is the only manual provisioning step.

```bash
BUCKET_NAME="your-unique-tf-state-bucket"
REGION="eu-north-1"

aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION \
  --create-bucket-configuration LocationConstraint=$REGION

aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Update the `backend "s3"` blocks in each Terraform module with this bucket name.

### Step 2 — Deploy Infrastructure (in order)

```bash
# Network foundation
cd awsTerraform/vpc
terraform init && terraform plan -out=./plan && terraform apply plan

# OIDC, KMS, IAM, allowlist bucket
cd ../security
terraform init && terraform plan -out=./plan && terraform apply plan

# ECR container registry
cd ../container-runtime
terraform init && terraform plan -out=./plan && terraform apply plan

# EKS cluster
cd ../eks
terraform init && terraform plan -out=./plan && terraform apply plan

# Kyverno + policies
cd ../kyverno
terraform init && terraform plan -out=./plan && terraform apply plan
```

### Step 3 — Configure GitHub Actions

Add the GitHub pipeline role ARN (output from security module) as a repository secret:

```
Settings → Secrets and variables → Actions → New repository secret
Name: AWS_ROLE_ARN
Value: <github_pipeline_role_arn output from security module>
```

### Step 4 — Sync Allowlist to S3

```bash
aws s3 cp security-objects/docker-base-image-allowlist.json \
  s3://wexlop-security-allowlists/allowlists/base-images.json
```

### Step 5 — Push to trigger pipeline

Commit a change to `web-server/` and the full pipeline runs automatically.

---

## Pipeline Diagram (GitHub Actions)

```
                    tfsec.yml
                    (on *.tf push/PR)
                         │
                    container-build.yml
                    (on web-server/ push/PR)
                         │
              ┌──────────┘
              │
              ▼
   container-security.yml (reusable)
   ├── AWS OIDC auth
   ├── Fetch S3 allowlist
   ├── check-base-image.py  → FAIL if image not approved
   └── hadolint             → FAIL if Dockerfile violations
              │
              ▼ (pass)
   build-scan-push
   ├── Build image (no-cache, SHA-tagged)
   ├── Trivy scan           → FAIL on CRITICAL/HIGH CVEs
   ├── Push to ECR          (main only, immutable tag)
   └── Output image digest
              │
              ▼ (main only)
   sign-and-attest
   ├── Cosign sign          (keyless OIDC, stored in ECR)
   ├── Syft SBOM            (SPDX JSON)
   └── Cosign attest        (SBOM attestation in ECR)
              │
              ▼ (at deploy time)
   Kyverno admission
   ├── Registry restriction
   ├── Signature verification
   ├── SBOM attestation check
   └── Pod security baseline
```
