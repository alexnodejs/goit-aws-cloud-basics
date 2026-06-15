# Значення, які знадобляться при створенні EC2.
# Переглянути після apply: terraform output

output "vpc_id" {
  description = "ID VPC goit-vpc-mds"
  value       = aws_vpc.goit_vpc_mds.id
}

output "public_subnet_id" {
  description = "Subnet ID для EC2 з публічною IP — підставляйте в поле Subnet при запуску інстанса"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "Subnet ID для ізольованих EC2 без виходу в інтернет"
  value       = aws_subnet.private.id
}

output "public_security_group_id" {
  description = "Security Group для EC2 у публічному сабнеті (SSH/HTTP/HTTPS)"
  value       = aws_security_group.public.id
}

output "private_security_group_id" {
  description = "Security Group для EC2 у приватному сабнеті (доступ лише з публічних інстансів)"
  value       = aws_security_group.private.id
}

output "availability_zone" {
  description = "Зона доступності, в якій створені перший публічний та приватний сабнети"
  value       = data.aws_availability_zones.available.names[0]
}

output "public_subnet_b_id" {
  description = "Subnet ID другого публічного сабнету (інша AZ, для ALB/ASG)"
  value       = aws_subnet.public_b.id
}

output "alb_dns_name" {
  description = "DNS-імʼя ALB — відкрийте http://<alb_dns_name> у браузері"
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "ARN Target Group, у яку ASG реєструє інстанси"
  value       = aws_lb_target_group.web.arn
}

output "asg_name" {
  description = "Назва Auto Scaling Group (тримає 2 інстанси)"
  value       = aws_autoscaling_group.web.name
}
