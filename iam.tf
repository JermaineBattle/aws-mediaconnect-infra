# IAM Role for MediaConnect to access VPC resources
resource "aws_iam_role" "mediaconnect" {
  name_prefix = "${var.project_name}-mediaconnect-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "mediaconnect.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-mediaconnect-role-${var.environment}"
  }
}

# IAM Policy for MediaConnect VPC interface access
resource "aws_iam_role_policy" "mediaconnect_vpc" {
  name_prefix = "mediaconnect-vpc-access-"
  role        = aws_iam_role.mediaconnect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# Wait for IAM role to propagate across AWS
resource "time_sleep" "wait_for_iam" {
  depends_on = [aws_iam_role.mediaconnect, aws_iam_role_policy.mediaconnect_vpc]

  create_duration = "15s"
}
