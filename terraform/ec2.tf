locals {
  ami_id = "ami-00857cb994754dd17"
}

resource "aws_instance" "vault_root_server" {
  count                  = var.vault_nodes
  ami                    = local.ami_id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.vault_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.self_hosted_runner.id

  user_data = templatefile("${path.module}/templates/userdata-vault.tpl", {
    tpl_vault_node_name    = "vault_1",
    tpl_vault_storage_path = "/opt/vault/data",
    tpl_aws_region         = var.aws_region,
    tpl_kms_id             = aws_kms_key.vault_example.id
    tpl_secret_name        = awscc_secretsmanager_secret.vault_root.secret_id
  })

  tags = {
    cluster_name = "vault-dev"
    Name         = "vault_1"
  }

  #   lifecycle {
  #     ignore_changes = [ami, tags]
  #   }
}


resource "aws_instance" "vault_node" {
  count                  = var.vault_nodes
  ami                    = local.ami_id
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.vault_nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.self_hosted_runner.id

  user_data = templatefile("${path.module}/templates/userdata-node.tpl", {
    tpl_vault_node_name    = "vault_2",
    tpl_vault_storage_path = "/opt/vault/data",
    tpl_aws_region         = var.aws_region,
    tpl_kms_id             = aws_kms_key.vault_example.id
    tpl_leader_addr        = aws_instance.vault_root_server[0].private_ip
    tpl_secret_name        = awscc_secretsmanager_secret.vault_root.secret_id
  })

  tags = {
    cluster_name = "vault-dev"
    Name         = "vault_2"
  }

  #   lifecycle {
  #     ignore_changes = [ami, tags]
  #   }
}
