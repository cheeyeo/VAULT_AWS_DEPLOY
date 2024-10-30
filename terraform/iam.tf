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
      "ec2:DescribeInstances",
      "ec2:DescribeTags"
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

  statement {
    sid = "VaultTLSSecrets"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    effect = "Allow"
    resources = [
      "arn:aws:secretsmanager:eu-west-2:035663780217:secret:VAULT_TLS_CERT-cfgPgg",
      "arn:aws:secretsmanager:eu-west-2:035663780217:secret:VAULT_TLS_PRIVKEY-jXrIEz"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups"
    ]
    resources = [
      "*"
    ]
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

# Policy for S3 Bucket for automated snapshot
data "aws_iam_policy_document" "autosnapshot" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::${local.snapshot_bucket}/*.snap",
      "arn:aws:s3:::${local.snapshot_bucket}/*/*.snap"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucketVersions",
      "s3:ListBucket"
    ]
    resources = ["arn:aws:s3:::${local.snapshot_bucket}"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.snapshot_bucket}",
      "arn:aws:s3:::${local.snapshot_bucket}/*"
    ]
  }
}

resource "aws_iam_role_policy" "autosnapshot_policy" {
  name = "VaultAutosnapshot"
  policy = data.aws_iam_policy_document.autosnapshot.json
  role = aws_iam_role.self_hosted_runner.name
}

# IAM role for vault restore scheduler
data "aws_iam_policy_document" "SchedulerTrustPolicy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

# https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command-setting-up.html
data aws_iam_policy_document "ssm_sendcommand_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
    ]
    resources = [aws_ssm_document.vault_restore.arn]
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "VaultRestoreScheduler"
  assume_role_policy = data.aws_iam_policy_document.SchedulerTrustPolicy.json
}

resource "aws_iam_role_policy" "scheduler_policy" {
  name = "VaultAutosnapshotScheduler"
  policy = data.aws_iam_policy_document.ssm_sendcommand_policy.json
  role = aws_iam_role.scheduler.name
}