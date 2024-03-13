terraform {
  required_version = ">= 0.15"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.36"
    }
  }
  backend "s3" {
    profile = "platform"
    bucket = "plat-engineering-terraform-st"
    key    = "sdlc/registry.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_iam_policy_document" "assume_role" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role" "ecr_allow_pushpull_role" {
  name = "AmazonECRAllowPushPullRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_policy" "ecr_allow_pushpull_policy" {
  name        = "AmazonECRAllowPushPullPolicy"

  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
        {
            Sid: "AllowPushPull",
            Effect: "Allow",
            Action: [
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:CompleteLayerUpload",
                "ecr:GetDownloadUrlForLayer",
                "ecr:InitiateLayerUpload",
                "ecr:PutImage",
                "ecr:UploadLayerPart"
            ],
            Resource = "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  role       = aws_iam_role.ecr_allow_pushpull_role.name
  policy_arn = aws_iam_policy.ecr_allow_pushpull_policy.arn
}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name                   = var.repository_name
  repository_read_write_access_arns = [aws_iam_role.ecr_allow_pushpull_role.arn]
  repository_force_delete           = true

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}