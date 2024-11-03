#!/usr/bin/env bash

set -x

echo "Updating base system..."

sudo yum-config-manager --enable rhui-REGION-rhel-server-releases-optional
sudo yum-config-manager --enable rhui-REGION-rhel-server-supplementary
sudo yum-config-manager --enable rhui-REGION-rhel-server-extras
sudo yum -y check-update
sudo yum install -q -y wget unzip bind-utils ntp jq curl
sudo systemctl start ntpd.service
sudo systemctl enable ntpd.service

USER_NAME="vault"
USER_COMMENT="HashiCorp Vault user"
USER_GROUP="vault"
USER_HOME="/srv/vault"

echo "Setup vault user..."
sudo /usr/sbin/groupadd --force --system $${USER_GROUP}

sudo /usr/sbin/adduser \
      --system \
      --gid $${USER_GROUP} \
      --home $${USER_HOME} \
      --no-create-home \
      --comment "$${USER_COMMENT}" \
      --shell /bin/false \
      $${USER_NAME}  >/dev/null

echo "Downloading vault..."
VAULT_VERSION=${tpl_vault_version}
curl -Lo /tmp/vault.zip https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip

echo "Installing vault..."

cd /tmp
sudo unzip -o /tmp/vault.zip -d /usr/local/bin/
sudo chmod 0755 /usr/local/bin/vault
sudo chown vault:vault /usr/local/bin/vault
sudo mkdir -pm 0755 /etc/vault.d

echo "Granting mlock syscall to vault binary"
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

echo "Creating vault service file..."
SYSTEMD_DIR="/etc/systemd/system"

sudo tee $${SYSTEMD_DIR}/vault.service <<EOF
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $$MAINPID
KillMode=control-group
KillSignal=SIGTERM
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 0664 $${SYSTEMD_DIR}/vault*

sudo rm -rf /tmp/vault.zip

# Get Private IP address
PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

echo "Configuring vault..."

sudo mkdir -pm 0755 ${tpl_vault_storage_path}
sudo chown -R vault:vault ${tpl_vault_storage_path}
sudo chmod -R a+rwx ${tpl_vault_storage_path}

# Audit logs
echo "Enable Vault audit logs..."
sudo mkdir -pm 0755 ${tpl_vault_storage_path}/logs
sudo chown -R vault:vault ${tpl_vault_storage_path}/logs
sudo chmod -R a+rwx ${tpl_vault_storage_path}/logs

sudo touch ${tpl_vault_storage_path}/logs/vault_audit.log
sudo chown vault:vault ${tpl_vault_storage_path}/logs/vault_audit.log
vault audit enable file file_path=${tpl_vault_storage_path}/logs/vault_audit.log

# Place CA key and certificate.
echo "Enable TLS certificates..."
sudo mkdir -pm 0755 ${tpl_vault_storage_path}/tls
sudo chown -R vault:vault ${tpl_vault_storage_path}/tls
sudo chmod -R a+rwx ${tpl_vault_storage_path}/tls

# get the private key
sudo aws --region ${tpl_aws_region} secretsmanager get-secret-value \
  --secret-id VAULT_TLS_PRIVKEY \
  --query 'SecretBinary' \
  --output text | base64 --decode > ${tpl_vault_storage_path}/tls/vault_key.pem

sudo aws --region ${tpl_aws_region} secretsmanager get-secret-value \
  --secret-id VAULT_TLS_CERT \
  --query 'SecretBinary' \
  --output text | base64 --decode > ${tpl_vault_storage_path}/tls/vault_ca.crt


sudo chmod 0600 ${tpl_vault_storage_path}/tls/vault_ca.crt
sudo chown vault:vault ${tpl_vault_storage_path}/tls/vault_ca.crt

sudo chmod 0640 ${tpl_vault_storage_path}/tls/vault_key.pem
sudo chown vault:vault ${tpl_vault_storage_path}/tls/vault_key.pem


sudo tee /etc/vault.d/vault.hcl <<EOF
api_addr = "https://vault.${tpl_domain}:8200"
cluster_addr = "https://$${PRIVATE_IP}:8201"

disable_mlock = true
ui=true

storage "raft" {
  path    = "${tpl_vault_storage_path}"
  node_id = "$${INSTANCE_ID}"

  retry_join {
    auto_join_scheme = "https"
    auto_join = "provider=aws region=${tpl_aws_region} tag_key=cluster_name tag_value=vault-dev"
    leader_tls_servername = "vault.${tpl_domain}"
    leader_client_cert_file = "${tpl_vault_storage_path}/tls/vault_ca.crt"
    leader_client_key_file = "${tpl_vault_storage_path}/tls/vault_key.pem"
  }
}

listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = 0
  tls_cert_file = "${tpl_vault_storage_path}/tls/vault_ca.crt"
  tls_key_file = "${tpl_vault_storage_path}/tls/vault_key.pem"
}

seal "awskms" {
  region = "${tpl_aws_region}"
  kms_key_id = "${tpl_kms_id}"
}
EOF

sudo chown -R vault:vault /etc/vault.d
sudo chmod -R 0644 /etc/vault.d/*

sudo systemctl enable vault
sudo systemctl start vault