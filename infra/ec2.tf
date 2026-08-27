data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "wireguard" {
  key_name   = "wireguard-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "wireguard" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.wireguard.id]
  key_name               = aws_key_pair.wireguard.key_name
  ipv6_address_count     = 1

  # Ставит только пакеты и форвардинг. Ключи и wg0.conf приезжают со старого
  # сервера отдельно — в user_data им не место.
  user_data = <<-EOT
    #!/bin/bash
    set -eux
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y wireguard qrencode

    cat > /etc/sysctl.d/99-wireguard.conf <<'SYSCTL'
    net.ipv4.ip_forward=1
    net.ipv6.conf.all.forwarding=1
    SYSCTL
    sysctl --system
  EOT

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_size_gb
    delete_on_termination = true
    encrypted             = true
  }

  lifecycle {
    # Свежий AMI от Canonical иначе заставит пересоздать сервер вместе с /etc/wireguard.
    ignore_changes = [ami, user_data]
  }

  tags = {
    Name = "wireguard-server"
  }
}

# Endpoint для клиентов. Между аккаунтами EIP не переносится — старый
# 18.156.108.6 останется в 229535221334, у пиров меняется строка Endpoint.
resource "aws_eip" "wireguard" {
  domain = "vpc"

  tags = {
    Name = "wireguard-eip"
  }
}

resource "aws_eip_association" "wireguard" {
  instance_id   = aws_instance.wireguard.id
  allocation_id = aws_eip.wireguard.id
}
