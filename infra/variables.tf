variable "aws_profile" {
  description = "Профиль AWS для туннеля."
  type        = string
  default     = "k8s-lab-admin"
}

variable "instance_type" {
  description = "Тип EC2-инстанса WireGuard."
  type        = string
  default     = "t3.micro"
}

variable "root_size_gb" {
  description = "Размер корневого тома EC2 в GiB."
  type        = number
  default     = 8
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/personal.pub"
}

variable "wg_port" {
  type    = number
  default = 51820
}
