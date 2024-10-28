data "aws_ami" "default" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "vault_template" {
  name = "vault_template"

  iam_instance_profile {
    name = aws_iam_instance_profile.self_hosted_runner.name
  }

  image_id                             = data.aws_ami.default.id
  instance_type                        = "t2.micro"
  instance_initiated_shutdown_behavior = "terminate"

  metadata_options {
    http_endpoint = "enabled"
    # http_tokens            = "required"
    instance_metadata_tags = "enabled"
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    subnet_id                   = module.vpc.private_subnets[0]
    security_groups             = [aws_security_group.vault_nodes.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      cluster_name = "vault-dev"
    }
  }

  update_default_version = true

  user_data = base64encode(templatefile("${path.module}/templates/userdata-vault2.tpl", {
    tpl_vault_storage_path = "/opt/vault/data",
    tpl_aws_region         = var.aws_region,
    tpl_kms_id             = aws_kms_key.vault_example.id
  }))
}