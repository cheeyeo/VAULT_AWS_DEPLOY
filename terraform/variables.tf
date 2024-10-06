variable "self_ec2_instance_role" {
  description = "EC2 Instance role name"
  type        = string
  default     = "CustomEC2InstanceRole"
}

variable "vault_server_names" {
  description = "Names of the Vault nodes that will join the cluster"
  type        = list(string)
  default     = ["vault_2", "vault_3"]
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "vault_nodes" {
  description = "Number of vault nodes to create"
  type        = number
  default = 0
}

variable "ami_id" {
  description = "AMI of EC2 vault instance"
  type = string
  default = ""
}