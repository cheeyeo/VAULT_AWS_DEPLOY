#!/usr/bin/env bash

set -x

# Get Private IP address
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Configuring vault..."

sudo mkdir -pm 0755 ${tpl_vault_storage_path}
sudo chown -R vault:vault ${tpl_vault_storage_path}
sudo chmod -R a+rwx ${tpl_vault_storage_path}

sudo tee /etc/vault.d/vault.hcl <<EOF
storage "raft" {
  path    = "${tpl_vault_storage_path}"
  node_id = "${tpl_vault_node_name}"
  
  retry_join {
    leader_api_addr = "http://${tpl_leader_addr}:8200"
    auto_join_scheme = "http"
  }
}

listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = true
}

seal "awskms" {
  region = "${tpl_aws_region}"
  kms_key_id = "${tpl_kms_id}"
}

api_addr = "http://$${PRIVATE_IP}:8200"
cluster_addr = "http://$${PRIVATE_IP}:8201"
disable_mlock = true
ui=true
EOF

sudo chown -R vault:vault /etc/vault.d

sudo systemctl enable vault
sudo systemctl start vault

sleep 30
# Read root token temporarily from secretsmanager
VAULT_TOKEN=$(aws --region ${tpl_aws_region} secretsmanager get-secret-value --secret-id ${tpl_secret_name} --query SecretString --output text | jq '.root_token')

# echo $VAULT_TOKEN > /home/ssm-user/root_token
# sudo chown ssm-user:ssm-user /home/ssm-user/root_token
# echo $VAULT_TOKEN > /home/ssm-user/.vault-token
# sudo chown ssm-user:ssm-user /home/ssm-user/.vault-token

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$VAULT_TOKEN

sleep 10

echo "Testing vault setup"
vault secrets enable -path=kv kv-v2
vault kv put kv/apikey foo=bar
vault kv get kv/apikey