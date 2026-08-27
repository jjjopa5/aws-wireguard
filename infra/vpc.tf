# Сеть повторяет старый аккаунт один в один: адресация внутри VPC на клиентов
# не влияет, но так проще сверять и переносить.
resource "aws_vpc" "main" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true

  tags = {
    Name = "wireguard-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = "10.0.1.0/24"
  availability_zone               = var.az
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, 0)
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = true

  tags = {
    Name = "wireguard-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "wireguard-igw"
  }
}

# Egress-only IGW, а не обычный: наружу по IPv6 ходить можно, снаружи к нам — нет.
# Endpoint WireGuard остаётся на IPv4 EIP, входящий IPv6 не нужен.
resource "aws_egress_only_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "wireguard-eigw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "wireguard-rt"
  }
}

resource "aws_route" "default_v4" {
  route_table_id         = aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "default_v6" {
  route_table_id              = aws_route_table.main.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.main.id
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}
