
# Available AZs in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# Current AWS account ID (for ARN construction if needed)
data "aws_caller_identity" "current" {}

# Latest self-owned Packer AMI for the app
data "aws_ami" "my_ami" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["docker-compose-ami-*"]
  }
}
