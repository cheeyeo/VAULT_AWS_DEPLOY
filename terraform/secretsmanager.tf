# Create a secret manager secret to store vault root token
resource "awscc_secretsmanager_secret" "vault_root" {
  name        = "VAULT_ROOT_TOKEN_${random_string.default.result}"
  description = "To store the initial Vault root token during init"
}

# Get the ARN of the TLS secrets manager certificate
data "aws_secretsmanager_secret" "vault_tls_cert" {
  name = "VAULT_TLS_CERT"
}

# Get data of TLS secrets manager private key
data "aws_secretsmanager_secret" "vault_tls_privkey" {
  name = "VAULT_TLS_PRIVKEY"
}