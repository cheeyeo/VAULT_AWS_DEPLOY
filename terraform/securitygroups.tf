resource "aws_security_group" "vault_nodes" {
  name        = "vault_nodes"
  description = "Vault nodes traffic"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "vault_nodes"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vault_nodes_tls" {
  security_group_id = aws_security_group.vault_nodes.id
  cidr_ipv4   = module.vpc.vpc_cidr_block
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "vault_nodes_api" {
  security_group_id = aws_security_group.vault_nodes.id
  cidr_ipv4   = module.vpc.vpc_cidr_block
  from_port   = 8200
  to_port     = 8200
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "vault_nodes_cluster" {
  security_group_id = aws_security_group.vault_nodes.id
  cidr_ipv4   = module.vpc.vpc_cidr_block
  from_port   = 8201
  to_port     = 8201
  ip_protocol = "tcp"
}

# internal traffic for self join of nodes?
resource "aws_vpc_security_group_ingress_rule" "vault_nodes_ingress" {
  security_group_id            = aws_security_group.vault_nodes.id
  referenced_security_group_id = aws_security_group.vault_nodes.id
  ip_protocol                  = "-1"
}

# egress 
resource "aws_vpc_security_group_egress_rule" "vault_nodes_egress" {
  security_group_id = aws_security_group.vault_nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Define ingress rule to reference ELB sg
resource "aws_vpc_security_group_ingress_rule" "vault_nodes_elb" {
  count                        = var.vault_nodes > 0 ? 1 : 0
  security_group_id            = aws_security_group.vault_nodes.id
  referenced_security_group_id = aws_security_group.vault_elb[0].id
  from_port                    = 8200
  to_port                      = 8200
  ip_protocol                  = "tcp"
}


# Security group for Load Balancer
resource "aws_security_group" "vault_elb" {
  count       = var.vault_nodes > 0 ? 1 : 0
  name        = "vault_elb"
  description = "Vault ELB"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "vault_elb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vault_elb_all_ingress" {
  count             = var.vault_nodes > 0 ? 1 : 0
  security_group_id = aws_security_group.vault_elb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  to_port           = 0
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "vault_elb_all_egress" {
  count             = var.vault_nodes > 0 ? 1 : 0
  security_group_id = aws_security_group.vault_elb[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 0
  to_port           = 0
  ip_protocol       = "-1"
}


# Define the remaining two egress rules using 
resource "aws_vpc_security_group_egress_rule" "vault_elb_cluser_egress" {
  count                        = var.vault_nodes > 0 ? 1 : 0
  from_port                    = 8200
  to_port                      = 8200
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.vault_elb[0].id
  referenced_security_group_id = aws_security_group.vault_nodes.id
}

resource "aws_vpc_security_group_egress_rule" "vault_elb_api_egress" {
  count                        = var.vault_nodes > 0 ? 1 : 0
  from_port                    = 8201
  to_port                      = 8201
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.vault_elb[0].id
  referenced_security_group_id = aws_security_group.vault_nodes.id
}