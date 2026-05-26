# TLS certificate for the site hostname (DNS validation)
resource "aws_acm_certificate" "aws_acm_certificate" {
  domain_name = var.alb_dns_name

  subject_alternative_names = compact([
    var.alb_dns_name != var.domain_name ? var.domain_name : null
  ])

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cert"
  }
}

# Route 53 records required for ACM DNS validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.aws_acm_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.alxphelps.zone_id
}

# Wait until ACM marks the certificate as issued
resource "aws_acm_certificate_validation" "aws_acm_certificate_validation" {
  certificate_arn         = aws_acm_certificate.aws_acm_certificate.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]

  timeouts {
    create = "10m"
  }
}
