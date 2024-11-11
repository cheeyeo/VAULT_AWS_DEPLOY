variable "self_ec2_instance_role" {
  description = "EC2 Instance role name"
  type        = string
  default     = "CustomEC2SSMRole"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "vault_snapshot_bucket" {
  type    = string
  default = "vault-snapshots"
}

variable "vault_domain" {
  type = string
  description = "Domain name for vault cluster. Set in network load balancer."
}

variable "vault_version" {
  type = string
  default = "1.18.0"
  description = "Version of vault to install"
}