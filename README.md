# DevSecOps Lab
The purpose of this repo is to showcase my skills with DevSecOps, 
to build the lab we assume a state where the AWS Account is _Empty_
meaning this lab will go through basic vpc creation with terraform,
and secure modules for various aws resources, which can be leveraged 
any time that resource is required. From there security hardening is
implemented at every layer of the stack — from infrastructure provisioning 
through to runtime threat detection.

The lab is structured in phases:

1. **Foundation** — VPC, subnets, routing, and remote state bootstrapping
2. **Secure Modules** — reusable Terraform modules for EC2, S3, IAM, and other 
   AWS resources with security best practices baked in by default
3. **Container Platform** — EKS cluster provisioned via Terraform with private 
   node groups, IRSA, and KMS encryption
4. **Kubernetes Hardening** — RBAC, Network Policies, Pod Security Standards, 
   and admission control via Kyverno
5. **CI/CD with Security Gates** — GitHub Actions pipeline with IaC scanning, 
   secret detection, container image scanning, and SAST at every stage
6. **Runtime Security** — Falco for real-time threat detection, Prometheus and 
   Grafana for observability, and CloudTrail for audit logging

# Container Build Security Pipeline
Container security starts at the authoring of the dockerfile, which is why we shift left as much as possible,
initially we check the base images pinned sha256 hashes against an s3 datastore containing allowed container images,
this is completed with a simple immutable version controlled s3 bucket, a python script in /scripts and a workflow for 
container-security which is called by the container-build gh action as a pre-build task. 
<img width="1460" height="626" alt="image" src="https://github.com/user-attachments/assets/604e2392-6fea-4084-8f84-65ed298b1c91" />

# Container Runtime Security
todo

# ECR/EKS Setup
todo


### Features & Tech Stack   
| Feature | Technology |
|---|---|
| Infrastructure Provisioning | Terraform |
| Cloud Provider | AWS (EKS, ECR, VPC, IAM, KMS, Secrets Manager, S3) |
| State Management | S3 + DynamoDB |
| CI/CD Pipeline | GitHub Actions |
| GitOps | ArgoCD |
| IaC & Image Scanning | tfsec, checkov, trivy, kube-linter |
| SAST & DAST | semgrep, OWASP ZAP |
| Secret & Supply Chain | gitleaks, Cosign, Syft |
| Kubernetes Hardening | RBAC, Network Policies, Pod Security Standards |
| Admission Control | Kyverno |
| Runtime Threat Detection | Falco |
| Observability | Prometheus, Grafana, CloudWatch, CloudTrail |
| Certificate Management | cert-manager |

# Setup and replication
1. clone&fork repo
2. setup empty aws account, run aws configure in local cli so terraform has credentials to use
3. setup an empty bucket for terraform state (only manual provisioning step!)
  ```
# Create the bucket
aws s3api create-bucket \
  --bucket your-unique-name \
  --region eu-north-1 \
  --create-bucket-configuration LocationConstraint=eu-north-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket your-unique-name \
  --versioning-configuration Status=Enabled

# Block all public access
aws s3api put-public-access-block \
  --bucket your-unique-name \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```
5. cd awsTerraform/vpc -> terraform plan -out=./plan -> terraform apply plan
6. cd ../security -> terraform plan -out=./plan -> terraform apply plan
7. go to your github repo and add the secret output as AWS_ROLE_ARN under settings -> secrets -> actions (for testing use repo secret, for real deployment we would have multiple environment secrets)
8. ...

