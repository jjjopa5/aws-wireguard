output "server_ip" {
  description = "Elastic IP адрес WireGuard сервера"
  value       = aws_eip.wireguard.public_ip
}

output "ssh_command" {
  description = "Команда для подключения по SSH"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${aws_eip.wireguard.public_ip}"
}

output "server_ipv6" {
  description = "Глобальный IPv6 адрес WireGuard сервера"
  value       = length(aws_instance.wireguard.ipv6_addresses) > 0 ? aws_instance.wireguard.ipv6_addresses[0] : "не назначен"
}