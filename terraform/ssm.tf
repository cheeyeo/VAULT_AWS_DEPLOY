resource "random_password" "password" {
  length  = 32
  special = true
}

resource "aws_ssm_document" "vault" {
  name            = "setup_vault"
  document_type   = "Command"
  document_format = "YAML"

  content = templatefile("${path.module}/test.yaml", {
    tpl_aws_region = var.aws_region,
    tpl_secret_id  = awscc_secretsmanager_secret.vault_root.secret_id
    tpl_password   = random_password.password.result
  })
}
