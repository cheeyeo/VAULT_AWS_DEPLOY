#!/usr/bin/env bash


set -ex

# To create secrets after certs created
aws secretsmanager create-secret --name "VAULT_TLS_PRIVKEY" \
   --description "Vault Private key file" \
   --secret-binary fileb://tls/live/example.com/privkey.pem

aws secretsmanager create-secret --name "VAULT_TLS_CERT" \
   --description "Vault Certificate file" \
   --secret-binary fileb://tls/live/example.com/fullchain.pem

# TO update after renewal:
aws secretsmanager update-secret --secret-id "VAULT_TLS_PRIVKEY" \
   --description "Update Vault Private key file for 29/10/2024" \
   --secret-binary fileb://tls/live/example.com/privkey.pem

aws secretsmanager update-secret --secret-id "VAULT_TLS_CERT" \
   --description "Update Vault Certificate file 29/10/2024" \
   --secret-binary fileb://tls/live/example.com/fullchain.pem


# To get file contents:
aws secretsmanager get-secret-value \
  --secret-id VAULT_TLS_PRIVKEY \
  --query 'SecretBinary' \
  --output text | base64 --decode > priv.pem


aws secretsmanager get-secret-value \
  --secret-id VAULT_TLS_CERT \
  --query 'SecretBinary' \
  --output text | base64 --decode > cert.pem