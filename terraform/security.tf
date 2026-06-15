# Безпека: Security Groups (stateful, на рівні EC2) та Network ACL (stateless, на рівні сабнету).

# --- Security Group для публічного сабнету ---------------------------------

# Підставляйте цю групу при створенні EC2 у публічному сабнеті.
# Stateful: відповідь на дозволений вхідний запит виходить автоматично.
resource "aws_security_group" "public" {
  name        = "goit-vpc-mds-public-sg"
  description = "Public EC2: SSH, HTTP, HTTPS from the internet"
  vpc_id      = aws_vpc.goit_vpc_mds.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Ping inside VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "goit-vpc-mds-public-sg"
  }
}

# --- Security Group для приватного сабнету ---------------------------------

# Підставляйте цю групу при створенні EC2 у приватному сабнеті.
# Вхідний трафік дозволено лише від інстансів з публічної групи —
# класичний bastion-патерн: у приватну EC2 заходимо через публічну.
resource "aws_security_group" "private" {
  name        = "goit-vpc-mds-private-sg"
  description = "Private EC2: traffic only from public security group"
  vpc_id      = aws_vpc.goit_vpc_mds.id

  ingress {
    description     = "All traffic from public instances"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.public.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "goit-vpc-mds-private-sg"
  }
}

# --- Security Group для Application Load Balancer ---------------------------

# ALB приймає HTTP-трафік з інтернету та форвардить його на інстанси.
resource "aws_security_group" "alb" {
  name        = "goit-vpc-mds-alb-sg"
  description = "ALB: HTTP from the internet"
  vpc_id      = aws_vpc.goit_vpc_mds.id

  ingress {
    description = "HTTP from the internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "goit-vpc-mds-alb-sg"
  }
}

# --- Security Group для вебінстансів за ALB ---------------------------------

# Інстанси приймають HTTP лише від ALB (а не напряму з інтернету).
# SSH дозволено з var.ssh_allowed_cidr. Egress відкритий, щоб user_data
# міг встановити nginx через dnf.
resource "aws_security_group" "web" {
  name        = "goit-vpc-mds-web-sg"
  description = "Web EC2 behind ALB: HTTP only from ALB, SSH from allowed CIDR"
  vpc_id      = aws_vpc.goit_vpc_mds.id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "goit-vpc-mds-web-sg"
  }
}

# --- Network ACL для публічного сабнету ------------------------------------

# NACL stateless: правила перевіряються для кожного пакета окремо,
# тому для відповідей сервера потрібно явно відкрити ephemeral-порти 1024-65535.
resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.goit_vpc_mds.id
  subnet_ids = [aws_subnet.public.id, aws_subnet.public_b.id]

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Відповіді на вихідні запити самої EC2 (наприклад, yum install)
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    rule_no    = 140
    protocol   = "icmp"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
    icmp_type  = -1
    icmp_code  = -1
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "goit-vpc-mds-public-nacl"
  }
}

# --- Network ACL для приватного сабнету ------------------------------------

# Трафік дозволено лише в межах VPC — інтернет повністю закритий,
# що узгоджується з відсутністю NAT Gateway у приватній route table.
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.goit_vpc_mds.id
  subnet_ids = [aws_subnet.private.id]

  ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "goit-vpc-mds-private-nacl"
  }
}
