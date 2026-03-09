resource "aws_key_pair" "wireguard" {
  key_name   = "wireguard-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_instance" "wireguard" {
  ami                         = "ami-0a628e1e89aaedf80"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.main.id
  vpc_security_group_ids      = [aws_security_group.wireguard.id]
  key_name                    = aws_key_pair.wireguard.key_name
  associate_public_ip_address = true

  tags = {
    Name = "wireguard-server"
  }
}

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