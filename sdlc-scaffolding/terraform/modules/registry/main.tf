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

  repository_name = "platform-engineering"

  repository_read_write_access_arns = [aws_iam_role.ecr_allow_pushpull_role.arn]

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