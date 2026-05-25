# Terraform — portfolio VPC, ALB, ASG, ACM, Route 53, IAM

Single-root Terraform stack for a public **portfolio** site on AWS: VPC, Application Load Balancer, Auto Scaling Group, ACM TLS, DNS, and IAM for GitHub Actions deploy, app EC2, and Packer builds.

## What this creates

### Networking

- **VPC** (`10.0.0.0/16`) with an Internet Gateway and **two public subnets** in two AZs (ALB requirement).
- **Security groups**
  - ALB: HTTP `80` and HTTPS `443` from the internet.
  - App instances: HTTPS `443` only from the ALB security group.

### Load balancing and compute

- **Public ALB**: listener `80` → **301 redirect to `443`**; listener `443` → HTTPS target group on instance port `443`.
- **Target group**: HTTPS health checks to `health_check_path` (default `/health`); matcher `200-399`.
- **ASG + launch template**
  - Latest **self-owned** AMI matching name `docker-compose-ami-*` (`data.aws_ami.my_ami`).
  - Public IP, `${project_name}-app-profile` instance profile.
  - **User data** (`userdata.sh`): updates the host, starts nginx, downloads `s3://342989859526.tfstate/portfolio-app.tar.gz`, extracts to `/portfolio`, and runs the app via **Docker Compose** on port `3000`.

### DNS and TLS

- **ACM certificate** for `alb_dns_name`, with optional SAN for `domain_name` when they differ; **DNS validation** records in the existing hosted zone.
- **Route 53** (existing zone): looks up hosted zone `alxphelps.com` and creates:
  - **A alias** to the ALB for the relative name derived from `alb_dns_name` (e.g. `portfolio` for `portfolio.alxphelps.com`).
  - **A alias** for `domain_name` (apex).

This stack does **not** create a new hosted zone. The zone must already exist and be delegated at your registrar.

### IAM

| Role / profile | Name pattern | Purpose |
|----------------|--------------|---------|
| GitHub deploy | `${project_name}-github-deploy` | OIDC trust for `github_org` / `github_repo`; inline policy for **SSM Run Command** and EC2 describe (for deploy workflows). |
| App instance | `${project_name}-app-instance` | EC2 role: **AmazonSSMManagedInstanceCore** + inline **S3 read/list** (`s3:Get*`, `s3:List*` on `*`). |
| App instance profile | `${project_name}-app-profile` | Attached to ASG instances (output: `app_instance_profile_name`). |
| Packer | `packer` | EC2 role for image builds: read objects in **`342989859526.tfstate`** (Terraform state bucket; also used for `portfolio-app.tar.gz`). |
| Packer instance profile | `packer` | Use as `iam_instance_profile` in Packer builder config. |

Also creates a **GitHub OIDC provider** for `token.actions.githubusercontent.com` (skip or import if one already exists in the account).

### State backend

Remote state in **S3**: bucket `342989859526.tfstate`, key `terraform-infra/terraform.tfstate`, region `us-east-1` (see `versions.tf`).

## Prerequisites

- Terraform **>= 1.5**, AWS credentials with permission to manage these resources.
- **Route 53**: public hosted zone for your domain already exists (today the data source is fixed to **`alxphelps.com`** in `route53.tf`).
- **AMI**: at least one **self-owned** AMI whose name matches `docker-compose-ami-*` in the target region (typically built with Packer using the `packer` instance profile).
- **S3**: `portfolio-app.tar.gz` present at `s3://342989859526.tfstate/portfolio-app.tar.gz` if you rely on default user data.
- **GitHub Actions** (optional): AWS credentials or OIDC role access for `terraform init` / `plan` / `apply` in CI.

## Configuration

Copy and edit `terraform.tfvars` (see the checked-in example values for `portfolio` / `alxphelps.com`):

| Variable | Purpose |
|----------|---------|
| `aws_region` | Region for all resources (default `us-east-1`). |
| `project_name` | Prefix for tags and many resource names. |
| `domain_name` | Root domain (e.g. `alxphelps.com`). |
| `alb_dns_name` | Browser hostname and ACM primary name (e.g. `portfolio.alxphelps.com`). |
| `github_org`, `github_repo` | Repo allowed to assume the deploy role. |
| `github_branches` | Optional OIDC ref filter; empty = any ref in the repo. |
| `instance_type`, `min_size`, `max_size`, `desired_capacity` | ASG sizing. |
| `health_check_path` | HTTPS path for ALB health checks. |

## Quick start

```bash
cd terraform-infra
# Edit terraform.tfvars for your domain, GitHub repo, and capacity

terraform init
terraform plan
terraform apply
```

After apply, confirm DNS points at the ALB (`site_fqdn` output). If you use a new ACM name, validation CNAMEs are created automatically in the existing zone.

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id`, `public_subnet_ids` | Network IDs |
| `alb_dns_name`, `alb_zone_id` | ALB endpoint (before / beside custom DNS) |
| `route53_zone_id`, `route53_name_servers` | Existing zone ID and NS (for registrar reference) |
| `acm_certificate_arn` | Issued certificate ARN |
| `github_oidc_provider_arn`, `github_deploy_role_arn` | GitHub Actions AWS auth |
| `app_instance_profile_name` | ASG instance profile |
| `site_fqdn` | Public hostname (`alb_dns_name`) |

## GitHub Actions

Workflows in `.github/workflows/`:

- **`plan.yml`**: on push/PR to `main` — `fmt -check`, `validate`, `plan`.
- **`apply.yml`**: manual **`workflow_dispatch`** — `apply -auto-approve`.

For app deploys (SSM, etc.), use output **`github_deploy_role_arn`** with `aws-actions/configure-aws-credentials`, `permissions: id-token: write`, and a trust policy subject matching your `github_org` / `github_repo` (and optional `github_branches`).

Configure these **repository secrets** (Settings → Secrets and variables → Actions) so CI can access the S3 backend and AWS APIs:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM access key for Terraform in CI |
| `AWS_SECRET_ACCESS_KEY` | Matching secret key |

Workflows set `aws-region` to `us-east-1` (same as the state backend and default `aws_region`).

## Packer

Build AMIs with instance profile **`packer`**. That role can list and read objects in the `342989859526.tfstate` bucket (including Terraform state and the app artifact path used by user data). Name built AMIs so they match `docker-compose-ami-*` for the ASG launch template lookup.

## Notes

- **OIDC provider**: If `token.actions.githubusercontent.com` already exists in the account, import it or reference the existing ARN instead of creating a duplicate.
- **Route 53 data source**: Zone lookup is currently hardcoded to `alxphelps.com` in `route53.tf`; generalizing to `var.domain_name` would be a small follow-up change.
- **Target group HTTPS**: The ALB forwards HTTPS to instances on port `443` (nginx). Health checks use HTTPS to `health_check_path`; the ALB does not validate a self-signed cert on the instance backend.
- **S3 on app instances**: `${project_name}-app-instance` can list and read any S3 bucket in the account (`s3:Get*`, `s3:List*`). Scope down in production if needed.
- **User data**: Requires Docker (and compose) on the AMI; adjust `userdata.sh` if your artifact path or layout changes.
