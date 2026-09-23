locals {
  # ALB requires subnets in at least 2 AZs — minimum layout while keeping both subnets public.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # OIDC: restrict to your repo; optional branch filter
  github_oidc_subjects = length(var.github_branches) > 0 ? [
    for b in var.github_branches : "repo:${var.github_org}/${var.github_repo}:${b}"
    ] : [
    "repo:${var.github_org}/${var.github_repo}:*"
  ]

  # Relative record name inside the hosted zone (e.g. "www" or "" for apex)
  dns_relative_name = (
    lower(var.alb_dns_name) == lower(var.domain_name)
    ? ""
    : trimsuffix(lower(var.alb_dns_name), ".${lower(var.domain_name)}")
  )
}

variable "aws_region" {
  type        = string
  description = "AWS region for all resources (ALB and ACM must match)."
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Generic name prefix for tags and some resource names."
}

variable "domain_name" {
  type        = string
  description = "Root domain for ACM cert and Route 53 (e.g. example.com)."
}

variable "alb_dns_name" {
  type        = string
  description = "Hostname for the site (e.g. www.example.com or example.com). Must be under domain_name."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for ASG."
  default     = "t3.small"
}

variable "github_org" {
  type        = string
  description = "GitHub organization or user name for OIDC trust (repo subject)."
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without org) allowed to assume the deploy role."
}

variable "github_branches" {
  type        = list(string)
  description = "Ref paths allowed in OIDC sub claim (e.g. [\"ref:refs/heads/main\"]). Empty = any branch."
  default     = []
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "health_check_path" {
  type        = string
  description = "HTTPS path on the instance for ALB health checks."
  default     = "/health"
}

variable "github_url" {
  type        = string
  description = "GitHub repository URL for the infrastructure source code."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, staging, prod) for tagging."
}