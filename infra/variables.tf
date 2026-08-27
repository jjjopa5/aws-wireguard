variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "az" {
  type    = string
  default = "eu-central-1a"
}

variable "aws_profile" {
  description = "Профиль нового аккаунта 347288885877. Старый 229535221334 доживает свои кредиты."
  type        = string
  default     = "k8s-lab-admin"
}

variable "instance_type" {
  description = "Один в один со старым сервером."
  type        = string
  default     = "t3.micro"
}

variable "root_size_gb" {
  description = "На старом сервере 8 GB; там же лежали docker-образы бота, которые сюда не едут."
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
