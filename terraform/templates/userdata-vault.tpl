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
    auto_join_scheme = "http"
    auto_join = "provider=aws region=${tpl_aws_region} tag_key=cluster_name tag_value=vault-dev"
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
sudo chmod -R 0644 /etc/vault.d/*

sudo systemctl enable vault
sudo systemctl start vault

%{ if vault_role == "leader" ~}
sleep 60

vault operator init -address="http://127.0.0.1:8200" -recovery-shares 1 -recovery-threshold 1 -format=json > /tmp/key.json

echo "Enable Vault audit logs..."
sudo touch /var/log/vault_audit.log
sudo chown vault:vault /var/log/vault_audit.log
vault audit enable file file_path=/var/log/vault_audit.log


VAULT_TOKEN=$(cat /tmp/key.json | jq -r ".root_token")
RECOVERY_KEYS_B64=$(cat /tmp/key.json | jq -r ".recovery_keys_b64[]")
RECOVERY_KEYS_HEX=$(cat /tmp/key.json | jq -r ".recovery_keys_hex[]")
# Save token temporarily to secrets manager..
json=$(cat <<-END
    {
        "root_token": "$${VAULT_TOKEN}",
        "recovery_keys_b64": "$${RECOVERY_KEYS_B64}",
        "recovery_keys_hex": "$${RECOVERY_KEYS_HEX}"
    }
END
)

echo $json > /tmp/res.json
aws --region ${tpl_aws_region} secretsmanager put-secret-value --secret-id ${tpl_secret_name} --secret-string file:///tmp/res.json

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$VAULT_TOKEN

echo "Waiting for Vault to finish preparations (10s)"
sleep 10

echo "Enabling kv-v2 secrets engine and inserting secret"
vault secrets enable -path=secret kv-v2
vault kv put secret/apikey webapp=ABB39KKPTWOR832JGNLS02
vault kv get secret/apikey

echo "Setting up user auth..."
vault auth enable userpass
vault auth enable okta
%{ endif ~}