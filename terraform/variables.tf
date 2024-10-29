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
  type = string
  default = "vault-snapshots"
}