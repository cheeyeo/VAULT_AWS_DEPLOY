data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "custom-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

resource "aws_security_group" "vault_nodes" {
  name        = "vault_nodes"
  description = "Vault nodes traffic"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "vault_nodes"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }


  # Vault API traffic
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  # Vault cluster traffic
  ingress {
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  # Internal Traffic
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define ingress rule to reference ELB sg
resource "aws_security_group_rule" "ingress_vault_elb" {
  count    = var.vault_nodes
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vault_nodes.id
  source_security_group_id = aws_security_group.vault_elb[0].id
}

# Security group for Load Balancer
resource "aws_security_group" "vault_elb" {
  count    = var.vault_nodes
  name        = "vault_elb"
  description = "Vault ELB"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "vault_elb"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define the remaining two egress rules using 
resource "aws_security_group_rule" "egress_vault_core" {
  count    = var.vault_nodes
  type                     = "egress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vault_elb[0].id
  source_security_group_id = aws_security_group.vault_nodes.id
}

resource "aws_security_group_rule" "egress_vault_core2" {
  count    = var.vault_nodes
  type                     = "egress"
  from_port                = 8201
  to_port                  = 8201
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vault_elb[0].id
  source_security_group_id = aws_security_group.vault_nodes.id
}

# Create ELB target group
resource "aws_lb_target_group" "tstvault" {
  count    = var.vault_nodes
  name     = "tst-vault"
  port     = 8200
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/v1/sys/health?standbyok=true"
    protocol            = "HTTP"
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    healthy_threshold   = 3
    matcher             = "200-399"
  }
}

# Create target group attachment for vault root node
resource "aws_lb_target_group_attachment" "tstvault" {
  count            = var.vault_nodes
  target_group_arn = aws_lb_target_group.tstvault[0].arn
  target_id        = aws_instance.vault_root_server[0].id
  port             = 8200
}

# Create target group attachment for vault worker nodes
resource "aws_lb_target_group_attachment" "tstvault2" {
  count            = var.vault_nodes
  target_group_arn = aws_lb_target_group.tstvault[0].arn
  target_id        = aws_instance.vault_node[0].id
  port             = 8200
}

# Create Listener
resource "aws_lb_listener" "ui" {
  count             = var.vault_nodes
  load_balancer_arn = aws_lb.vault[0].arn
  port              = "8200"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tstvault[0].arn
  }
}

# Create Load Balancer
resource "aws_lb" "vault" {
  count              = var.vault_nodes
  name               = "vault-elb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in module.vpc.public_subnets : subnet]
  security_groups    = [aws_security_group.vault_elb[0].id]
  tags = {
    Environment = "vault-dev"
  }
}