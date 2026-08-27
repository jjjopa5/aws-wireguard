output "server_ip" {
  description = "Elastic IP — новый Endpoint для всех пиров."
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
  description = "Глобальный IPv6 сервера. Новый префикс — старый 2a05:d014:1c16:5b00::/56 остаётся в старом аккаунте."
  value       = length(aws_instance.wireguard.ipv6_addresses) > 0 ? aws_instance.wireguard.ipv6_addresses[0] : "не назначен"
}
