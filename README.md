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
run it only on worker nodes with its leader_api url set...


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