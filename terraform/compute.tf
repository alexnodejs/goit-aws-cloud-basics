# Обчислення: AMI, Launch Template (nginx через user_data) та Auto Scaling Group.

# --- AMI -------------------------------------------------------------------

# Останній офіційний образ Amazon Linux 2023 (x86_64) від AWS.
# t3.small — архітектура x86_64, тому беремо саме x86_64-образ.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Launch Template -------------------------------------------------------

# Шаблон, з якого Auto Scaling Group запускає однакові інстанси.
# user_data при першому старті ставить nginx і генерує HTML-сторінку,
# що показує, який саме інстанс відповів (instance-id / hostname / AZ) —
# так видно роботу балансування при оновленні через ALB.
resource "aws_launch_template" "web" {
  name_prefix   = "goit-mds-ec2-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.web.id]

  # Вимагаємо IMDSv2 (токен) — безпечніший доступ до метаданих інстанса.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf install -y nginx

    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
    IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/placement/availability-zone)
    HOST=$(hostname -f)

    cat > /usr/share/nginx/html/index.html <<HTML
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>MDS GOIT Load Balancer</title></head>
    <body>
      <h1>MDS GOIT Load Balancer</h1>
      <p>Instance: $IID</p>
      <p>Host: $HOST</p>
      <p>AZ: $AZ</p>
    </body>
    </html>
    HTML

    systemctl enable --now nginx
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "goit-mds-ec2"
    }
  }
}

# --- Auto Scaling Group ----------------------------------------------------

# Тримає рівно 2 інстанси (min=2, max=2, desired=2) у двох публічних сабнетах
# (дві AZ) і реєструє їх у Target Group балансувальника.
# health_check_type = "ELB" + grace 180s — ASG дає час nginx піднятися,
# перш ніж вважати інстанс нездоровим.
resource "aws_autoscaling_group" "web" {
  name                      = "goit-mds-asg"
  min_size                  = 2
  max_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.public.id, aws_subnet.public_b.id]
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "goit-mds-ec2"
    propagate_at_launch = true
  }
}
