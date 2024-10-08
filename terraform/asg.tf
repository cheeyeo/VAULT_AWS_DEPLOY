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
  count                = var.vault_nodes > 0 ? 1 : 0
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

  name_prefix = "vault-dev-"

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = local.instance_name
  }

  target_group_arns   = [aws_lb_target_group.tstvault[0].arn]
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
}

