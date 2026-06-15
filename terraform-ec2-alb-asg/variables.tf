# Усі змінні мають значення за замовчуванням — terraform apply працює без додаткових параметрів.

variable "aws_profile" {
  description = "Профіль AWS CLI, від імені якого створюються ресурси (налаштовується через aws configure --profile)"
  type        = string
  default     = "goit-aws-mds"
}

variable "aws_region" {
  description = "Регіон AWS, у якому створюється мережа"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR-блок усієї VPC (65 536 адрес)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR публічного сабнету (256 адрес)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR приватного сабнету (256 адрес)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR другого публічного сабнету в іншій AZ (потрібен для ALB у двох зонах)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "instance_type" {
  description = "Тип EC2-інстансів за ALB"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Назва наявної EC2 key pair для SSH (необовʼязково; null — без ключа)"
  type        = string
  default     = null
}

variable "ssh_allowed_cidr" {
  description = "Звідки дозволено SSH до публічних EC2. Для безпеки краще вказати свою IP, наприклад \"203.0.113.10/32\""
  type        = string
  default     = "0.0.0.0/0"
}
