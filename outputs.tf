output "vpc_id" {
  value       = aws_vpc.aws_vpc.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Public subnet IDs (used by ALB and ASG)"
}

output "alb_dns_name" {
  value       = aws_lb.portfolio.dns_name
  description = "ALB DNS name (before DNS cutover)"
}

output "alb_zone_id" {
  value       = aws_lb.portfolio.zone_id
  description = "ALB hosted zone ID for alias records"
}

output "route53_zone_id" {
  value       = data.aws_route53_zone.alxphelps.zone_id
  description = "Route 53 hosted zone ID"
}

output "route53_name_servers" {
  value       = data.aws_route53_zone.alxphelps.name_servers
  description = "Delegate your domain at the registrar to these NS records"
}

output "acm_certificate_arn" {
  value       = aws_acm_certificate.aws_acm_certificate.arn
  description = "Issued ACM certificate ARN (after validation)"
}

output "github_oidc_provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "GitHub OIDC provider ARN"
}

output "github_deploy_role_arn" {
  value       = aws_iam_role.github_deploy.arn
  description = "IAM role ARN for GitHub Actions (configure aws-actions/configure-aws-credentials with this role)"
}

output "app_instance_profile_name" {
  value       = aws_iam_instance_profile.portfolio.name
  description = "EC2 instance profile name attached to ASG instances"
}

output "site_fqdn" {
  value       = var.alb_dns_name
  description = "Public hostname for the site (ACM + Route 53)"
}
