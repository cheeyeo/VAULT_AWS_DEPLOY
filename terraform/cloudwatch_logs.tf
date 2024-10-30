# Log group for vault server setup script
resource "aws_cloudwatch_log_group" "vault_setup_logs" {
  name              = "vault_setup"
  retention_in_days = 7

  tags = {
    Name = "vault-dev"
  }
}

# Log group for vault server syslog
resource "aws_cloudwatch_log_group" "vault_syslog" {
  name              = "vault_syslog"
  retention_in_days = 7

  tags = {
    Name = "vault-dev"
  }
}

# Log group for vault restore
resource "aws_cloudwatch_log_group" "vault_restore" {
  name              = "vault_restore"
  retention_in_days = 7

  tags = {
    Name = "vault-dev"
  }
}