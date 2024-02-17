data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

variable "collection_name" {
  description = "Name of the OpenSearch Serverless collection."
  default     = "example-collection"
}

# Creates an encryption security policy
resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name        = "example-encryption-policy"
  type        = "encryption"
  description = "encryption policy for ${var.collection_name}"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/${var.collection_name}"
        ],
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}

# Creates a collection
resource "aws_opensearchserverless_collection" "collection" {
  name = var.collection_name

  depends_on = [aws_opensearchserverless_security_policy.encryption_policy]
}

# Creates a VPC endpoint
resource "aws_opensearchserverless_vpc_endpoint" "vpc_endpoint" {
  name               = "example-vpc-endpoint"
  vpc_id             = aws_vpc.vpc.id
  subnet_ids         = [aws_subnet.subnet.id]
  security_group_ids = [aws_security_group.security_group.id]
}

# Creates a network security policy
resource "aws_opensearchserverless_security_policy" "network_policy" {
  name        = "example-network-policy"
  type        = "network"
  description = "public access for dashboard, VPC access for collection endpoint"
  policy = jsonencode([
    {
      Description = "VPC access for collection endpoint",
      Rules = [
        {
          ResourceType = "collection",
          Resource = [
            "collection/${var.collection_name}"
          ]
        }
      ],
      AllowFromPublic = false,
      SourceVPCEs = [
        aws_opensearchserverless_vpc_endpoint.vpc_endpoint.id
      ]
    },
    {
      Description = "Public access for dashboards",
      Rules = [
        {
          ResourceType = "dashboard"
          Resource = [
            "collection/${var.collection_name}"
          ]
        }
      ],
      AllowFromPublic = true
    }
  ])
}

# Creates a data access policy
resource "aws_opensearchserverless_access_policy" "data_access_policy" {
  name        = "example-data-access-policy"
  type        = "data"
  description = "allow index and collection access"
  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index",
          Resource = [
            "index/${var.collection_name}/*"
          ],
          Permission = [
            "aoss:*"
          ]
        },
        {
          ResourceType = "collection",
          Resource = [
            "collection/${var.collection_name}"
          ],
          Permission = [
            "aoss:*"
          ]
        }
      ],
      Principal = [
        data.aws_caller_identity.current.arn
      ]
    }
  ])
}