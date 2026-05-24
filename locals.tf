
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_ami" "my_ami" {
  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["docker-compose-ami-*"]
  }
}