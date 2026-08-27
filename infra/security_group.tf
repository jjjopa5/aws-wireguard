# Правила отдельными ресурсами, а не inline-блоками: inline дерутся с отдельными
# ресурсами и молча затирают их при apply.
resource "aws_security_group" "wireguard" {
  name        = "wireguard-sg"
  description = "WireGuard VPN server"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "wireguard-sg"
  }
}

# Как на старом сервере — SSH открыт наружу. Белый IP у владельца динамический,
# сузить до /32 значит рисковать локаутом при смене адреса.
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.wireguard.id
  description       = "SSH"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "wireguard" {
  security_group_id = aws_security_group.wireguard.id
  description       = "WireGuard"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "udp"
  from_port         = var.wg_port
  to_port           = var.wg_port
}

resource "aws_vpc_security_group_egress_rule" "all_v4" {
  security_group_id = aws_security_group.wireguard.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all_v6" {
  security_group_id = aws_security_group.wireguard.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}
