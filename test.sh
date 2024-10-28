#!/usr/bin/env bash


set -e

# aws secretsmanager create-secret --name "VAULT_TLS_PRIVKEY" \
#    --description "Vault Private key file" \
#    --secret-binary fileb://tls/archive/teka-teka.xyz/privkey1.pem

# aws secretsmanager create-secret --name "VAULT_TLS_CERT" \
#    --description "Vault Certificate file" \
#    --secret-binary fileb://tls/archive/teka-teka.xyz/cert1.pem

# aws secretsmanager create-secret --name "VAULT_TLS_CHAIN" \
#    --description "Vault Chain file" \
#    --secret-binary fileb://tls/archive/teka-teka.xyz/fullchain1.pem


aws secretsmanager get-secret-value \
  --secret-id VAULT_TLS_PRIVKEY \
  --query 'SecretBinary' \
  --output text | base64 --decode > priv.pem


aws secretsmanager get-secret-value \
  --secret-id VAULT_TLS_CERT \
  --query 'SecretBinary' \
  --output text | base64 --decode > cert.pem

aws secretsmanager get-secret-value \
  --secret-id VAULT_TLS_CHAIN \
  --query 'SecretBinary' \
  --output text | base64 --decode > chain.pem