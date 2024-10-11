### Vault on AWS


https://github.com/btkrausen/hashicorp

https://www.taccoform.com/posts/pkr_p1/


```
packer init .

packer build .

packer build --var-file=inputs.auto.pkrvars.hcl vault.pkr.hcl
```

To format hcl files:
```
terragrunt hclfmt
```



* Create AMI in AWS using Packer

( Issue with SSM agent running after creating instance from AMI )

When running an instance in default VPC, instance need to have public IP enabled else the ssm agent won't work

When running in private subnet, need to ensure its in private VPC with nat gateway...



* Use AMI to provision new EC2 instances with custom user data script to update config file and install vault



User data script for raft on AWS:

https://github.com/hashicorp/learn-vault-raft/blob/main/raft-storage/aws/

https://github.com/hashicorp/learn-vault-raft/blob/main/raft-storage/aws/templates/userdata-vault-transit.tpl


https://support.hashicorp.com/hc/en-us/articles/360002046068-Where-are-My-Vault-Logs-and-How-do-I-Share-Them-with-HashiCorp-Support

```
sudo journalctl -b --no-pager -u vault
```

raft operator join only works before the vault is unsealed !!!
https://developer.hashicorp.com/vault/docs/commands/operator/raft#join

vault operator raft join http://<leader ip>:8200


The process is for AWS KMS seal is:

* Only initialize the leader node and get it configured first
```
vault operator init -recovery-shares 1 -recovery-threshold 1 -format=json > /tmp/key.json
```

* For each child node, run the join command:
```
export VAULT_ADDR=http://127.0.0.1:8200

vault operator raft join http://10.0.1.61:8200
```

Note that the token for login on all nodes is the same one from the leader node hence need some form of external storage such as AWS SECRETS?

=============================================================================================


Trying to replace above with retry_join..

retry_join should not be run on leader node as it causes a loop !! 
its expecting vault to be initialized...
run it only on leader node 


===========================================================================================

How to test IAM role by assuming it in cli...


https://repost.aws/knowledge-center/iam-assume-role-cli



https://developer.hashicorp.com/vault/docs/concepts/integrated-storage#server-to-server-communication

https://github.com/btkrausen/hashicorp/tree/master/vault

https://github.com/hashicorp/learn-vault-raft/tree/main/raft-storage


### Load Balancers

https://support.hashicorp.com/hc/en-us/articles/4413810165395-Best-Practices-AWS-NLB-configuration-for-Vault

https://repost.aws/knowledge-center/public-load-balancer-private-ec2

https://stackoverflow.com/a/78692375


* The NETWORK load balancer needs to point to public subnets
* A custom security group needs to be associated with the ELB:
    - INGRESS all traffic ( need work )
    - EGRESS
        - Custom TCP, TCP, 8200, sg for instance
        - Custom TCP, TCP, 8201, sg for instance
* Security group for vault instance:
    - Add a rule on the instance security group to allow traffic from the security group that's assigned to the load balancer.
        - Custom TCP, TCP, 8200, sg for ELB



=========================================================

### Issues

* Redirect vault server logs to syslog for sending to cloudwatch; also need to setup cloudwatch agent

ref: https://github.com/robertdebock/terraform-aws-vault/blob/master/scripts/cloudwatch.sh

* How to run command on instance once its ready from ASG?


* For ASG we need to turn on autocleanup of dead raft peers:
( run on one of the nodes in cluster )

( below needs to be converted into script to run via SSM RunCommand )

```
export VAULT_ADDR=http://127.0.0.1:8200

vault operator init -address="http://127.0.0.1:8200" -recovery-shares 1 -recovery-threshold 1 -format=json > /tmp/key.json

VAULT_TOKEN=$(cat /tmp/key.json | jq -r ".root_token")
RECOVERY_KEYS_B64=$(cat /tmp/key.json | jq -r ".recovery_keys_b64[]")
RECOVERY_KEYS_HEX=$(cat /tmp/key.json | jq -r ".recovery_keys_hex[]")
# Save token temporarily to secrets manager..
json=$(cat <<-END
    {
        "root_token": "${VAULT_TOKEN}",
        "recovery_keys_b64": "${RECOVERY_KEYS_B64}",
        "recovery_keys_hex": "${RECOVERY_KEYS_HEX}"
    }
END
)

echo $json > /tmp/res.json
aws --region ${tpl_aws_region} secretsmanager put-secret-value --secret-id ${tpl_secret_name} --secret-string file:///tmp/res.json

export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$VAULT_TOKEN

echo "Waiting for Vault to finish preparations (10s)"
sleep 10

echo "Enable Vault audit logs..."
sudo touch /var/log/vault_audit.log
sudo chown vault:vault /var/log/vault_audit.log
vault audit enable file file_path=/var/log/vault_audit.log

echo "Enabling kv-v2 secrets engine and inserting secret"
vault secrets enable -path=secret kv-v2
vault kv put secret/apikey webapp=ABB39KKPTWOR832JGNLS02
vault kv get secret/apikey

echo "Setting up user auth..."
vault auth enable userpass
vault auth enable okta

vault login $VAULT_TOKEN

vault operator raft autopilot set-config \
  -min-quorum=3 \
  -cleanup-dead-servers=true \
  -dead-server-last-contact-threshold=120
```


https://rpadovani.com/terraform-cloudinit



How to run command after instances in ASG are initialized???




To run command via ssm:
```
aws ssm send-command --document-name "setup_vault" --document-version "\$LATEST" --targets '[{"Key":"InstanceIds","Values":["i-07cad8dbb553d96cc", "i-06045a4819df6159f", "i-069a87320d3289988"]}]' --parameters '{}' --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --cloud-watch-output-config '{"CloudWatchOutputEnabled":true,"CloudWatchLogGroupName":"vault_setup"}' --region eu-west-2
```

```
aws ssm send-command --document-name "setup_vault" --document-version "\$LATEST" --targets '[{"Key":"tag:cluster_name","Values":["vault-dev"]}]' --parameters '{}' --timeout-seconds 600 --max-concurrency "50" --max-errors "0" --cloud-watch-output-config '{"CloudWatchOutputEnabled":true,"CloudWatchLogGroupName":"vault_setup"}' --region eu-west-2
```


https://pkg.go.dev/github.com/aws/aws-sdk-go-v2/aws

To run command via custom go lang app:
```
ASG="vault-dev DOC="setup_vault" CLOUDWATCH_LOG="vault_setup" go run testscript.go
```


https://docs.aws.amazon.com/autoscaling/ec2/userguide/tutorial-lifecycle-hook-lambda.html

### ON TLS SETUP

The only example from https://github.com/robertdebock/terraform-aws-vault is to use self-signed cert with the AWS CA added to it:

https://github.com/robertdebock/terraform-aws-vault/blob/master/templates/user_data_vault.sh.tpl#L82-L121


We can't use ACM as it doesn't provide a CA cert?


Example below of using LetsEncrypt for AWS:

https://medium.com/@mariarafique/a-step-by-step-guide-to-ssl-certification-with-certbot-and-nginx-on-an-ec2-instance-2f6245f37d4f
