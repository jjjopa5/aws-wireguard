output "server_ip" {
  description = "Публичный IPv4-адрес WireGuard-сервера."
  value       = aws_eip.wireguard.public_ip
}

output "wg_endpoint" {
  description = "Строка Endpoint целиком, как её вписывать в конфиги клиентов."
  value       = "${aws_eip.wireguard.public_ip}:${var.wg_port}"
}

output "ssh_command" {
  value = "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ubuntu@${aws_eip.wireguard.public_ip}"
}

output "server_ipv6" {
  description = "Глобальный IPv6-адрес сервера для исходящих соединений."
  value       = length(aws_instance.wireguard.ipv6_addresses) > 0 ? aws_instance.wireguard.ipv6_addresses[0] : "не назначен"
}
