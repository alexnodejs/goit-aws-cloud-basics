# Мережа: VPC, сабнети, Internet Gateway, таблиці маршрутизації.

# Список доступних зон доступності в обраному регіоні.
# Обидва сабнети розміщуємо в першій зоні (names[0]) — простіше для навчання.
data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC -------------------------------------------------------------------

# Віртуальна приватна мережа. DNS увімкнено, щоб EC2 отримували
# внутрішні DNS-імена та могли резолвити зовнішні домени.
resource "aws_vpc" "goit_vpc_mds" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "goit-vpc-mds"
  }
}

# --- Internet Gateway ------------------------------------------------------

# Шлюз в інтернет. Без нього жоден ресурс у VPC не має виходу назовні.
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.goit_vpc_mds.id

  tags = {
    Name = "goit-vpc-mds-igw"
  }
}

# --- Сабнети ---------------------------------------------------------------

# Публічний сабнет: EC2 тут автоматично отримують публічну IP
# (map_public_ip_on_launch = true) і мають прямий вихід в інтернет через IGW.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.goit_vpc_mds.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "goit-vpc-mds-public-subnet"
  }
}

# Другий публічний сабнет в іншій зоні доступності (names[1]).
# Потрібен, бо Application Load Balancer вимагає мінімум два сабнети у двох
# різних AZ. Тут також розміщуються EC2 з Auto Scaling Group.
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.goit_vpc_mds.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "goit-vpc-mds-public-subnet-b"
  }
}

# Приватний сабнет: без публічних IP та без маршруту в інтернет.
# EC2 тут доступні лише зсередини VPC (наприклад, з публічного сабнету).
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.goit_vpc_mds.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "goit-vpc-mds-private-subnet"
  }
}

# --- Таблиці маршрутизації -------------------------------------------------

# Публічна таблиця: весь зовнішній трафік (0.0.0.0/0) іде через Internet Gateway.
# Локальний маршрут усередині VPC (10.0.0.0/16) AWS додає автоматично.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.goit_vpc_mds.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "goit-vpc-mds-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Другий публічний сабнет користується тією ж публічною таблицею маршрутизації.
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Приватна таблиця: лише автоматичний локальний маршрут усередині VPC.
# Маршруту в інтернет немає — сабнет ізольований (NAT Gateway не використовуємо,
# бо він платний і для навчальних цілей не потрібен).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.goit_vpc_mds.id

  tags = {
    Name = "goit-vpc-mds-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
