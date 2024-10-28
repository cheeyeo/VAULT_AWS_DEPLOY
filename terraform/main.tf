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

# Create ELB target group
resource "aws_lb_target_group" "tstvault" {
  count = var.vault_nodes > 0 ? 1 : 0
  name  = "tst-vault"

  port     = 8200
  protocol = "TCP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/v1/sys/health?standbyok=true"
    protocol            = "HTTPS"
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    healthy_threshold   = 3
    matcher             = "200-399"
  }
}

# Create Listener
resource "aws_lb_listener" "ui" {
  count             = var.vault_nodes > 0 ? 1 : 0
  load_balancer_arn = aws_lb.vault[0].arn
  port              = "8200"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tstvault[0].arn
  }
}

# TODO: Create TCP 443 listener
# If you must ensure that the targets decrypt TLS traffic instead of the load balancer, you can create a TCP listener on port 443 instead of creating a TLS listener. With a TCP listener, the load balancer passes encrypted traffic through to the targets without decrypting it.
# https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-listeners.html
# https://vault.teka-teka.xyz

resource "aws_lb_listener" "tls" {
  count             = var.vault_nodes > 0 ? 1 : 0
  load_balancer_arn = aws_lb.vault[0].arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tstvault[0].arn
  }
}


# Create Load Balancer
resource "aws_lb" "vault" {
  count              = var.vault_nodes > 0 ? 1 : 0
  name               = "vault-elb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in module.vpc.public_subnets : subnet]
  security_groups    = [aws_security_group.vault_elb[0].id]
  tags = {
    Environment = "vault-dev"
  }
}

# TODO: Create a DNS A record for load balancer
resource "aws_route53_record" "vault" {
  zone_id = "Z03864671MW1Y4SKPIIL8"
  name    = "vault"
  type    = "A"
  alias {
    name                   = aws_lb.vault.dns_name
    zone_id                = aws_lb.vault.zone_id
    evaluate_target_health = false
  }
}