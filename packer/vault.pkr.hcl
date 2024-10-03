packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "${env("AWS_REGION")}"
}

variable "vault_zip" {
  type    = string
  default = "vault_1.17.6_linux_amd64.zip"
}

variable "vpc_id" {
  type    = string
  default = "vpc-06626bb552084b94b"
}

variable "subnet_id" {
  type    = string
  default = "subnet-090200863e9701b57"
}

data "amazon-ami" "amazon-linux-2" {
  filters = {
    name                = "amzn2-ami-hvm-*-x86_64-ebs"
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["amazon"]
  region      = var.aws_region
}

source "amazon-ebs" "amazon-ebs-amazonlinux-2" {
  ami_description             = "Vault - Amazon Linux 2"
  ami_name                    = "vault-amazonlinux2-vault-course-${regex_replace(timestamp(), "[- TZ:]", "")}"
  ami_virtualization_type     = "hvm"
  force_delete_snapshot       = true
  force_deregister            = true
  instance_type               = "t2.small"
  region                      = var.aws_region
  source_ami                  = data.amazon-ami.amazon-linux-2.id
  ssh_interface               = "session_manager"
  ssh_username                = "ec2-user"
  communicator                = "ssh"
  iam_instance_profile        = "CustomEC2SSMRole"

  tags = {
    Name = "HashiCorp Vault"
    OS   = "Amazon Linux 2"
  }
  subnet_id = var.subnet_id
  vpc_id    = var.vpc_id
}

build {
  sources = ["source.amazon-ebs.amazon-ebs-amazonlinux-2"]

  provisioner "file" {
    destination = "/tmp/vault.zip"
    source      = var.vault_zip
  }

  provisioner "file" {
    destination = "/tmp/vault.service"
    source      = "files/vault.service"
  }

  provisioner "shell" {
    scripts = [
      "files/bootstrap.sh",
    ]
  }
}