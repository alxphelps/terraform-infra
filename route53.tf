# Existing public hosted zone for the domain
data "aws_route53_zone" "alxphelps" {
  name         = "alxphelps.com."
  private_zone = false
}

# A record pointing the site hostname at the ALB
resource "aws_route53_record" "alb_alias" {
  zone_id = data.aws_route53_zone.alxphelps.zone_id
  name    = local.dns_relative_name
  type    = "A"

  alias {
    name                   = aws_lb.portfolio.dns_name
    zone_id                = aws_lb.portfolio.zone_id
    evaluate_target_health = true
  }
}

# A record pointing the domain apex at the ALB
resource "aws_route53_record" "root_alias" {
  zone_id = data.aws_route53_zone.alxphelps.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.portfolio.dns_name
    zone_id                = aws_lb.portfolio.zone_id
    evaluate_target_health = true
  }
}
