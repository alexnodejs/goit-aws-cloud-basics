# Балансування: Target Group, Application Load Balancer та HTTP-listener.

# --- Target Group ----------------------------------------------------------

# Група цілей, у яку Auto Scaling Group реєструє інстанси.
# ALB перевіряє "/" і вважає інстанс здоровим при HTTP 200.
resource "aws_lb_target_group" "web" {
  name        = "goit-mds-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.goit_vpc_mds.id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "goit-mds-tg"
  }
}

# --- Application Load Balancer ----------------------------------------------

# Зовнішній (internet-facing) ALB у двох публічних сабнетах (двох AZ).
resource "aws_lb" "web" {
  name               = "goit-mds-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public_b.id]

  tags = {
    Name = "goit-mds-alb"
  }
}

# --- Listener --------------------------------------------------------------

# Слухає HTTP 80 і форвардить увесь трафік у Target Group.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
