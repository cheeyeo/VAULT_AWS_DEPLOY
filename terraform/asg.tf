# Auto scaling group for vault nodes
resource "random_string" "default" {
  length  = 6
  numeric = false
  special = false
  upper   = false
}

locals {
  amount        = 3
  instance_name = "vault-dev-${random_string.default.result}"
}

resource "aws_autoscaling_group" "group" {
  default_cooldown     = 300
  health_check_type    = "ELB"
  termination_policies = ["OldestInstance"]
  desired_capacity     = 3
  max_size             = 3
  min_size             = 1

  launch_template {
    id      = aws_launch_template.vault_template.id
    version = "$Latest"
  }

  name = "vault-dev"

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = local.instance_name
  }

  target_group_arns   = [aws_lb_target_group.tstvault.arn]
  vpc_zone_identifier = module.vpc.private_subnets

  instance_refresh {
    preferences {
      instance_warmup        = 300
      min_healthy_percentage = 90
    }

    strategy = "Rolling"
  }

  lifecycle {
    ignore_changes = [desired_capacity, target_group_arns]
  }

  timeouts {
    delete = "15m"
  }

  wait_for_capacity_timeout = "0"
}

resource "terraform_data" "example" {
  depends_on = [aws_autoscaling_group.group, aws_ssm_document.vault, aws_cloudwatch_log_group.vault_setup_logs]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = "cd '${path.cwd}/testscript' && ls -al && ASG=\"${aws_autoscaling_group.group.name}\" DOC=\"${aws_ssm_document.vault.name}\" CLOUDWATCH_LOG=\"${aws_cloudwatch_log_group.vault_setup_logs.name}\" go run testscript.go"
  }
}