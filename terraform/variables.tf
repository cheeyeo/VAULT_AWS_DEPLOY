variable "self_ec2_instance_role" {
  description = "EC2 Instance role name"
  type        = string
  default     = "CustomEC2SSMRole"
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}