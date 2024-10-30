# Create a secret manager secret to store vault root token
resource "awscc_secretsmanager_secret" "vault_root" {
  name        = "VAULT_ROOT_TOKEN_${random_string.default.result}"
  description = "To store the initial Vault root token during init"
}