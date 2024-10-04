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
  default     = 1
}