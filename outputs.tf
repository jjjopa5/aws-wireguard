output "server_ip" {
  description = "Elastic IP адрес WireGuard сервера"
  value       = aws_eip.wireguard.public_ip
}

output "ssh_command" {
  description = "Команда для подключения по SSH"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${aws_eip.wireguard.public_ip}"
}