resource "aws_iam_role" "role" {
  name               = "gitlab-runner-${local.service_tags.Name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = local.service_tags
}

# This policy gives our bastion access to resources
resource "aws_iam_policy" "policy" {
  name = "gitlab-runner-policy-${local.service_tags.Name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::${var.gitlab_runner_cache_name}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateTags",
        "ec2:DescribeInstances",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:ImportKeyPair",
        "ec2:DeleteKeyPair",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances",
        "ec2messages:GetMessages",
        "ssm:GetDocument",
        "ssm:ListInstanceAssociations",
        "ssm:PutComplianceItems",
        "ssm:PutInventory",
        "ssm:UpdateInstanceAssociationStatus",
        "ssm:UpdateInstanceInformation"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF

}

resource "aws_iam_policy_attachment" "attach" {
  name       = "attachment"
  roles      = [aws_iam_role.role.name]
  policy_arn = aws_iam_policy.policy.arn
}


data "aws_secretsmanager_secret" "secret" {
  count = var.gitlab_config_secret_id != "none" ? 1 : 0
  name = var.gitlab_config_secret_id
}

# This policy gives us access to the config stored in secretsmanager
resource "aws_iam_policy" "config_policy" {
  count = var.gitlab_config_secret_id != "none" ? 1 : 0

  name = "gitlab-runner-config-policy-${local.service_tags.Name}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "${data.aws_secretsmanager_secret.secret[0].arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "attach_config" {
  count = var.gitlab_config_secret_id != "none" ? 1 : 0
  name       = "attachment"
  roles      = [aws_iam_role.role.name]
  policy_arn = aws_iam_policy.config_policy[0].arn
}

resource "aws_iam_instance_profile" "profile" {
  name = "gitlab-runner-profile-${local.service_tags.Name}"
  role = aws_iam_role.role.name
}

data "aws_iam_instance_profile" "worker_machine" {
  count = var.machine_iam_instance_profile != "" ? 1 : 0
  name  = var.machine_iam_instance_profile
}

resource "aws_iam_policy" "runner_pass_role_to_worker" {
  count = var.machine_iam_instance_profile != "" ? 1 : 0

  name   = "gitlab-runner-policy-pass-role-to-worker-${local.service_tags.Name}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "${data.aws_iam_instance_profile.worker_machine[0].role_arn}"
      ]
    }
  ]
}
EOF

}

resource "aws_iam_policy_attachment" "runner_pass_role_to_worker" {
  count = var.machine_iam_instance_profile != "" ? 1 : 0

  name       = "runner-pass-role-to-worker-${local.service_tags.Name}"
  roles      = [aws_iam_role.role.name]
  policy_arn = aws_iam_policy.runner_pass_role_to_worker[0].arn
}
