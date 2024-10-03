#!/usr/bin/env bash

set -e

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
sudo /usr/sbin/groupadd --force --system ${USER_GROUP}

sudo /usr/sbin/adduser \
      --system \
      --gid ${USER_GROUP} \
      --home ${USER_HOME} \
      --no-create-home \
      --comment "${USER_COMMENT}" \
      --shell /bin/false \
      ${USER_NAME}  >/dev/null

echo "Downloading vault..."
VAULT_VERSION=1.17.6
curl -Lo /tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip

echo "Installing vault..."

cd /tmp
sudo unzip -o /tmp/vault.zip -d /usr/local/bin/
sudo chmod 0755 /usr/local/bin/vault
sudo chown vault:vault /usr/local/bin/vault
sudo mkdir -pm 0755 /etc/vault.d

echo "Granting mlock syscall to vault binary"
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

echo "Copying vault service file..."
SYSTEMD_DIR="/etc/systemd/system"
sudo cp vault.service ${SYSTEMD_DIR}/vault.service
sudo chmod 0664 ${SYSTEMD_DIR}/vault*

sudo rm -rf /tmp/vault.zip
sudo rm -rf /tmp/vault.service