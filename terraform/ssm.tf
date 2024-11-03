resource "random_password" "password" {
  length  = 32
  special = true
}

resource "aws_ssm_document" "vault" {
  name            = "setup_vault"
  document_type   = "Command"
  document_format = "YAML"

  content = templatefile("${path.module}/setup_vault.yaml", {
    tpl_aws_region = var.aws_region,
    tpl_secret_id  = awscc_secretsmanager_secret.vault_root.secret_id
    tpl_password   = random_password.password.result
    tpl_s3_bucket  = local.snapshot_bucket
  })
}

# Creates a document to run vault restore on the leader node
resource "aws_ssm_document" "vault_restore" {
  name            = "setup_vault_restore"
  document_type   = "Command"
  document_format = "YAML"

  content = templatefile("${path.module}/setup_vault_restore.yaml", {
    tpl_s3_bucket = local.snapshot_bucket
  })
}

# Get the leader node id
data "aws_instance" "leader" {
  instance_tags = {
    ROLE = "LEADER"
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_route53_record.vault]
}

resource "aws_scheduler_schedule" "vault_restore" {
  depends_on = [aws_route53_record.vault]

  name = "vault_restore"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = "cron(0/5 * * * ? *)"
  schedule_expression_timezone = "Europe/London"

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ssm:sendCommand"
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      DocumentName    = "setup_vault_restore"
      DocumentVersion = "$LATEST"
      InstanceIds     = [data.aws_instance.leader.id]
      CloudWatchOutputConfig = {
        CloudWatchLogGroupName  = "vault_restore"
        CloudWatchOutputEnabled = true
      }
    })
  }
}
