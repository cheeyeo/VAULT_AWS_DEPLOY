### Vault on AWS

Two ways of running Vault on AWS:

* Via packer using custom AMI. Use custom AMI to provision new EC2 instances with custom user data script to update config file and install vault

* Via terraform 


### Run with packer

CD into `packer` directory and run:
```
packer init .

packer build .

packer build --var-file=inputs.auto.pkrvars.hcl vault.pkr.hcl
```

To format hcl files:
```
terragrunt hclfmt
```

### References

https://www.taccoform.com/posts/pkr_p1/


### Issues with running packer

* Issue with SSM agent running after creating instance from AMI

  When running an instance in default VPC, instance need to have public IP enabled else the SSM agent won't work

  When running in private subnet, need to ensure its in private VPC with NAT gateway...



### Run with terraform

This creates a 3 node vault cluster backed by an autoscaling group, running in a private vpc behind a public network load balancer.

Login to your aws profile / account first:
```
export AWS_PROFILE=xxx
export AWS_REGION=xxx
```

The setup only runs on TLS and requires a Route53 hosted zone for the domain. It's recommended to setup the root Route53 hosted zone and obtain the TLS certs via LetsEncrypt before continuing.

We only use the privkey.pem and fullchain.pem certificates from LetsEncrypt
```
aws secretsmanager create-secret --name "VAULT_TLS_PRIVKEY" \
   --description "Vault Private key file" \
   --secret-binary fileb://tls/live/example.com/privkey.pem

aws secretsmanager create-secret --name "VAULT_TLS_CERT" \
   --description "Vault Certificate file" \
   --secret-binary fileb://tls/live/example.com/fullchain.pem
```

There is an example of the above in `tls_test.sh` 


The following two articles may help you out:

* https://www.cheeyeo.dev/aws/letsencrypt/tls/certificate-manager/2024/10/23/letsencrypt-aws/

* https://www.cheeyeo.dev/aws/vault/terraform/2024/10/30/vault-cluster-aws/



Create a tfvars file with the following overrides:
```
cd terraform

cat <<EOF > example.tfvars
vault_domain="example.com"
vault_version="1.18.1"
EOF
```

Apply terraform:
```
cd terraform

terraform init

terraform plan -out=tfplan -var-file=example.tfvars

terraform apply tfplan
```

The logs are currently not streamed to Cloudwatch Logs yet so need to use journalctl on one of the instances to view the logs:

```
sudo journalctl -b --no-pager -u vault
```

The `testscript` folder contains a go-lang script which is run after the ASG is created in order to select the first ready EC2 instance in the cluster as the leader and runs the initial vault cluster setup SSM document on it. The script is defined in `setup_vault.yml`


To run command via custom go lang app:
```
ASG="vault-dev DOC="setup_vault" CLOUDWATCH_LOG="vault_setup" go run testscript.go
```


### Items of interest

* vault raft operator join only works if the vault is unsealed

  To join a new node to the cluster via CLI is:
  ```
  vault operator raft join http://<leader ip>:8200
  ```

  The standard manual setup process is:

  * Only initialize the leader node and get it configured first
    ```
    vault operator init -recovery-shares 1 -recovery-threshold 1 -format=json > /tmp/key.json
    ```

  * For each child node, run the join command:
    ```
    export VAULT_ADDR=http://127.0.0.1:8200

    vault operator raft join http://10.0.1.61:8200
    ```

  https://developer.hashicorp.com/vault/docs/commands/operator/raft#join


* We use a Network Load Balancer as we want the TLS termination to occur on the Vault instances rather than on the load balancer itself, which is why we avoid the ALB

* The NETWORK load balancer needs to point to public subnets
  
  A custom security group needs to be associated with the ELB:
    - INGRESS all traffic ( need work )
    - EGRESS
        - Custom TCP, TCP, 8200, sg for instance
        - Custom TCP, TCP, 8201, sg for instance
  
  Security group for vault instance:
    - Add a rule on the instance security group to allow traffic from the security group that's assigned to the load balancer.
    
    - Custom TCP, TCP, 8200, sg for ELB

  - https://support.hashicorp.com/hc/en-us/articles/4413810165395-Best-Practices-AWS-NLB-configuration-for-Vault

  - https://repost.aws/knowledge-center/public-load-balancer-private-ec2

  - https://stackoverflow.com/a/78692375


* To enable TLS on the NLB, we need to add both TCP:443 and TCP:8200 to the Network load balancer listeners. The TCP must be set to 443 so it passes encrypted traffic to the NLB without decrypting it first...


### TODO

* Redirect logs to cloudwatch

  Ref:
  
  * https://github.com/robertdebock/terraform-aws-vault/blob/master/scripts/cloudwatch.sh
  
  * https://rpadovani.com/terraform-cloudinit

  Requires setting up cloudwatch agent, syslog

* Create restore SSM command for raft storage

* Multi-region replication


### Resolved Issues

* The vault A record may not work sometimes after provisioning? Works better after creating separate hosted zone for vault subdomain ( DONE )

  https://shipit.dev/posts/failing-aws-route53-records.html

  ( Wait at least a minute or more before querying... )

  Try to create a new hosted zone for the subdomain:

  https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-routing-traffic-for-subdomains.html

  https://towardsaws.com/stand-alone-subdomains-on-aws-dns-with-terraform-a488275f204b


* Create raft backup storage to S3 ( DONE )

  Need to run cronjob via SSM and eventbridge?

  https://www.tecracer.com/blog/2023/06/replace-local-cronjobs-with-eventbridge/ssm.html


* Store the letsencrypt certs into secrets manager as binary files ( only use privkey and fullchain ) ( DONE )


* Linux DBUS leftover process issue ( DONE )

  https://github.com/hashicorp/vault/issues/22560

  https://support.hashicorp.com/hc/en-us/articles/20562543907859-Vault-1-13-7-and-Linux-DBus-leftover-processes

  NOTE: This is fixed by upgrading to 1.18.0. Older versions will need to try some of the techniques described in the second link but may also cause the vault binary to fail to start


* Restrict SSM SENDCOMMAND to only leader node ( DONE )

  https://docs.aws.amazon.com/systems-manager/latest/userguide/run-command-setting-up.html


### References

* https://pkg.go.dev/github.com/aws/aws-sdk-go-v2/aws

* https://github.com/btkrausen/hashicorp

* https://github.com/hashicorp/learn-vault-raft/blob/main/raft-storage/aws/

* https://github.com/hashicorp/learn-vault-raft/blob/main/raft-storage/aws/templates/userdata-vault-transit.tpl

* https://developer.hashicorp.com/vault/docs/concepts/integrated-storage#server-to-server-communication

* https://sysadmin.info.pl/en/blog/secure-secrets-management-using-hashicorp-vault-with-gitlab-ci-cd/