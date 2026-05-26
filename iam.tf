# GitHub Actions OIDC TLS thumbprint for the provider
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# OIDC identity provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = distinct(concat([data.tls_certificate.github.certificates[0].sha1_fingerprint], []))
}

# IAM role assumed by GitHub Actions via OIDC
resource "aws_iam_role" "github_deploy" {
  name = "${var.project_name}-github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          "ForAnyValue:StringLike" = {
            "token.actions.githubusercontent.com:sub" = local.github_oidc_subjects
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-deploy"
  }
}

# Inline policy: SSM deploy + ECR push/pull for GitHub Actions
resource "aws_iam_role_policy" "github_deploy" {
  name = "${var.project_name}-github-deploy-policy"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMRunCommand"
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommands",
          "ssm:ListCommandInvocations",
          "ssm:DescribeInstanceInformation",
          "ssm:CancelCommand"
        ]
        Resource = "*"
      },
      {
        Sid      = "DescribeEC2ForTargets"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeInstanceStatus", "ec2:DescribeTags"]
        Resource = "*"
      },
      {
        "Sid": "ECRLogin",
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken"
        ],
        "Resource": "*"
      },
      {
        "Sid": "ECRPull",
        "Effect": "Allow",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ],
        "Resource": [
          "arn:aws:ecr:us-east-1:342989859526:repository/alxphelps/portfolio"
          ]
      }
    ]
  })
}

# EC2 role for app instances in the ASG
resource "aws_iam_role" "app_instance" {
  name = "${var.project_name}-app-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-app-instance"
  }
}

# AWS managed policy: SSM Session Manager on app instances
resource "aws_iam_role_policy_attachment" "app_instance_ssm" {
  role       = aws_iam_role.app_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Inline policy: S3 read, ECR, and tfstate bucket access for app instances
resource "aws_iam_role_policy" "app_instance" {
  name = "${var.project_name}-app-instance-policy"
  role = aws_iam_role.app_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ReadAndList"
        Effect = "Allow"
        Action = [
          "s3:Get*",
          "s3:List*"
        ]
        Resource = "*"
      },
      {
        "Sid": "ECRLogin",
        "Effect": "Allow",
        "Action": [
          "ecr:GetAuthorizationToken"
        ],
        "Resource": "*"
      },
      {
        "Sid": "ECRPull",
        "Effect": "Allow",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ],
        "Resource": [
          "arn:aws:ecr:us-east-1:342989859526:repository/alxphelps/portfolio"
          ]
      },
      {
        Sid    = "ListTfstateBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::342989859526.tfstate"
      },
      {
        Sid    = "ReadTfstateObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::342989859526.tfstate/*"
      }
    ]
  })
}

# Instance profile attached to ASG launch template
resource "aws_iam_instance_profile" "portfolio" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app_instance.name

  tags = {
    Name = "${var.project_name}-app-profile"
  }
}

# EC2 role for Packer AMI builds
resource "aws_iam_role" "packer" {
  name = "packer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "packer"
  }
}

# Inline policy: read Terraform state bucket during Packer builds
resource "aws_iam_role_policy" "packer" {
  name = "packer"
  role = aws_iam_role.packer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListTfstateBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::342989859526.tfstate"
      },
      {
        Sid    = "ReadTfstateObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::342989859526.tfstate/*"
      }
    ]
  })
}

# Instance profile for Packer builder instances
resource "aws_iam_instance_profile" "packer" {
  name = "packer"
  role = aws_iam_role.packer.name

  tags = {
    Name = "packer"
  }
}
