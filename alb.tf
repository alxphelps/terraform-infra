# HTTPS target group for app instances behind the ALB
resource "aws_lb_target_group" "portfolio" {
  name     = "app-pub-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.aws_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    protocol            = "HTTPS"
    matcher             = "200-399"
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# Public application load balancer
resource "aws_lb" "portfolio" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# HTTP listener: redirect all traffic to HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.portfolio.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener: terminate TLS and forward to the target group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.portfolio.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.aws_acm_certificate_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portfolio.arn
  }

  depends_on = [aws_acm_certificate_validation.aws_acm_certificate_validation]
}
