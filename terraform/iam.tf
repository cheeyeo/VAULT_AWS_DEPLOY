# Self-hosted runner EC2 Instance Role
data "aws_iam_policy_document" "AWSEC2TrustPolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "self_hosted_runner" {
  name               = var.self_ec2_instance_role
  assume_role_policy = data.aws_iam_policy_document.AWSEC2TrustPolicy.json
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.self_hosted_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_full_access" {
  role       = aws_iam_role.self_hosted_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.self_hosted_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "self_hosted_runner" {
  name = var.self_ec2_instance_role
  role = aws_iam_role.self_hosted_runner.name
}

# Additional policies for KMS, S3, Cloudwatch
data "aws_iam_policy_document" "additional_vault_policies" {
  statement {
    sid = "EnableKMSForVaultAutoUnseal"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    effect    = "Allow"
    resources = [aws_kms_key.vault_example.arn]
  }

  statement {
    sid = "EnableKMSForRaftSnapshotsForS3"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey"
    ]
    effect    = "Allow"
    resources = [aws_kms_key.vault_example.arn]
  }

  statement {
    sid = "PermitEC2ApiAccessForCloudAutoJoin"
    actions = [
      "ec2:DescribeInstances"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    sid = "AccessSecretsManager"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:PutSecretValue",
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:CancelRotateSecret",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:UpdateSecret",
      "secretsmanager:GetRandomPassword",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:StopReplicationToReplica",
      "secretsmanager:ReplicateSecretToRegions",
      "secretsmanager:RestoreSecret",
      "secretsmanager:RotateSecret",
      "secretsmanager:UpdateSecretVersionStage",
      "secretsmanager:RemoveRegionsFromReplication"
    ]
    effect    = "Allow"
    resources = [awscc_secretsmanager_secret.vault_root.id]
  }
}

resource "aws_iam_policy" "additional_vault_policy" {
  name        = "AdditionalVaultPolicies"
  description = "Additional policies for Vault"
  policy      = data.aws_iam_policy_document.additional_vault_policies.json
}

resource "aws_iam_role_policy_attachment" "additional_vault_policies" {
  role       = aws_iam_role.self_hosted_runner.name
  policy_arn = aws_iam_policy.additional_vault_policy.arn
}