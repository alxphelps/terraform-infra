# IAM policy documents

## `terraform-ci-deploy-policy.json`

Customer-managed policy for an IAM user or role used by **GitHub Actions** (or local CI) to run `terraform init`, `plan`, and `apply` on this repository.

### What it allows

Compact JSON (under the IAM **6144** non-whitespace character limit for customer-managed policies):

| Area | Scope |
|------|--------|
| **S3** | State bucket `342989859526.tfstate`, prefix `terraform-infra/*` only |
| **EC2 / ASG / ELB / ACM** | `ec2:*`, `autoscaling:*`, `elasticloadbalancing:*`, `acm:*` in **`us-east-1`** |
| **Route 53** | `route53:*` on hosted zones and changes (records + ACM validation) |
| **IAM** | `iam:*` on `portfolio-*` / `packer` roles, matching instance profiles, and GitHub OIDC; `iam:Get*` / `iam:List*` for plan; `PassRole` to EC2; service-linked roles for ELB/ASG |

### Tradeoffs

- Uses **service wildcards** in `us-east-1` instead of enumerating every API — smaller policy, broader EC2/ELB/ASG/ACM permissions in that region.
- **IAM** is scoped to named role/profile/OIDC ARNs, not account-wide `iam:*`.

### What it does not allow

- Creating S3 buckets or Route 53 hosted zones
- `s3:*` outside the state prefix
- Other AWS regions
