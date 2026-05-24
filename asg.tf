resource "aws_launch_template" "portfolio" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.my_ami.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.portfolio.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.portfolio.id]
    delete_on_termination       = true
    device_index                = 0
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-app"
      Project = var.project_name
    }
  }

  user_data = base64encode(file("${path.module}/userdata.sh"))

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "portfolio" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = aws_subnet.public[*].id
  health_check_grace_period = 120
  health_check_type         = "ELB"
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size
  max_size                  = var.max_size

  launch_template {
    id      = aws_launch_template.portfolio.id
    version = "$Latest"
  }

  #suspended_processes = ["ReplaceUnhealthy"]

  target_group_arns = [aws_lb_target_group.portfolio.arn]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = false
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb_listener.https]
}
