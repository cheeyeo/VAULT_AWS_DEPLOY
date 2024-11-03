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

===================================================================================

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

https://rpadovani.com/terraform-cloudinit


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



==================================================================================================

28/10/2024

Managed to get TLS working with Network Load Balancer with LetsEncrypt cert

Need to add both TCP:443 and TCP:8200 to the Network load balancer listeners
The TCP must be set to 443 so it passes encrypted traffic to the LB without decrypting it first...


### TODO

* Create raft backup storage to S3 ( DONE )

Need to run cronjob via SSM and eventbridge?

https://www.tecracer.com/blog/2023/06/replace-local-cronjobs-with-eventbridge/ssm.html


* Store the letsencrypt certs into secrets manager as binary files ( only use privkey and fullchain ) ( DONE )

* Linux DBUS leftover process issue ( DONE )

  work on userdata-vault2.tpl

  https://github.com/hashicorp/vault/issues/22560

  https://support.hashicorp.com/hc/en-us/articles/20562543907859-Vault-1-13-7-and-Linux-DBus-leftover-processes


* Restrict SSM SENDCOMMAND to only leader node ( DONE )

  https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command-setting-up.html


* Redirect logs to cloudwatch

* Create restore SSM command for raft storage


* Multi-region replication


### Issues

Upgrade to v18.0.1 causes SSM agent permission issue on startup:

```
/var/lib/amazon/ssm/i-061d0f564e28c2fad/document/orchestration/7960290a-c665-48dd-ba26-67b0c1e28c49/example/_script.sh: line 3: /usr/local/bin/vault: Permission denied
```

Need to investigate if its an IAM role issue