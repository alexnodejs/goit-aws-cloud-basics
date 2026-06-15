# Terraform: VPC `goit-vpc-mds` — Покрокова інструкція

## Мета

За допомогою Terraform створити готову мережу в AWS: VPC `goit-vpc-mds` з публічним та приватним сабнетами, налаштованими таблицями маршрутизації, security groups та Network ACL. Після `terraform apply` мережа одразу готова для запуску EC2 — всі необхідні ID виводяться в outputs.

## Передумови

- AWS акаунт з доступом до консолі або CLI
- Встановлений AWS CLI (`aws --version`)
- Налаштований профіль `goit-aws-mds`:
  ```bash
  aws configure --profile goit-aws-mds
  ```
  (ввести Access Key ID, Secret Access Key, регіон `eu-central-1`, формат `json`)
- Перевірка профілю:
  ```bash
  aws sts get-caller-identity --profile goit-aws-mds
  ```
- Встановлений Terraform >= 1.5 (`terraform version`)
  - macOS: `brew install terraform`
  - Windows: `choco install terraform` або завантажити з [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)
- Регіон: `eu-central-1` (Frankfurt)

---

## Що буде створено

```
                         ┌──────────────────────────────────────────┐
   Інтернет ◄──────────► │ Internet Gateway (goit-vpc-mds-igw)      │
                         └────────────────────┬─────────────────────┘
                                              │
┌─────────────────────────────────────────────┼─────────────────────────────┐
│ VPC goit-vpc-mds (10.0.0.0/16)              │                             │
│                                             │                             │
│  ┌──────────────────────────────┐   ┌───────┴──────────────────────┐      │
│  │ Приватний сабнет             │   │ Публічний сабнет             │      │
│  │ 10.0.2.0/24                  │   │ 10.0.1.0/24                  │      │
│  │                              │   │                              │      │
│  │ • без публічних IP           │◄──┤ • авто-публічна IP для EC2   │      │
│  │ • без виходу в інтернет      │   │ • маршрут 0.0.0.0/0 → IGW    │      │
│  │ • доступ лише зсередини VPC  │   │ • SSH/HTTP/HTTPS ззовні      │      │
│  └──────────────────────────────┘   └──────────────────────────────┘      │
└────────────────────────────────────────────────────────────────────────────┘
```

| Ресурс | Назва | Призначення |
|---|---|---|
| VPC | `goit-vpc-mds` | Ізольована мережа `10.0.0.0/16` |
| Internet Gateway | `goit-vpc-mds-igw` | Вихід в інтернет для публічного сабнету |
| Subnet (public) | `goit-vpc-mds-public-subnet` | `10.0.1.0/24`, EC2 отримують публічну IP |
| Subnet (private) | `goit-vpc-mds-private-subnet` | `10.0.2.0/24`, без доступу з/до інтернету |
| Route Table (public) | `goit-vpc-mds-public-rt` | `0.0.0.0/0 → IGW` |
| Route Table (private) | `goit-vpc-mds-private-rt` | Лише локальні маршрути в межах VPC |
| Security Group (public) | `goit-vpc-mds-public-sg` | SSH (22), HTTP (80), HTTPS (443) ззовні |
| Security Group (private) | `goit-vpc-mds-private-sg` | Трафік лише від публічної security group |
| Network ACL (public) | `goit-vpc-mds-public-nacl` | 22/80/443 + ephemeral-порти |
| Network ACL (private) | `goit-vpc-mds-private-nacl` | Трафік лише в межах VPC |

> **Чому без NAT Gateway?** NAT Gateway дав би приватним EC2 вихід в інтернет, але коштує ~$32/міс. Для навчання він не потрібен — приватний сабнет демонструє повну ізоляцію.

---

## Крок 1: Ініціалізація

Перейти в папку `terraform/` та завантажити провайдер AWS:

```bash
cd terraform
terraform init
```

Очікуваний результат: `Terraform has been successfully initialized!`

---

## Крок 2: Перегляд плану

Подивитися, що саме Terraform збирається створити (нічого ще не створюється):

```bash
terraform plan
```

Очікуваний результат: `Plan: 12 to add, 0 to change, 0 to destroy.`

---

## Крок 3: Створення мережі

```bash
terraform apply
```

Terraform покаже план ще раз і запитає підтвердження — ввести `yes`.

Очікуваний результат: `Apply complete! Resources: 12 added` та блок `Outputs:` з ID-шниками.

> Усі параметри мають значення за замовчуванням. За бажанням можна звузити доступ по SSH до своєї IP:
> ```bash
> terraform apply -var="ssh_allowed_cidr=$(curl -s ifconfig.me)/32"
> ```

---

## Крок 4: Перевірка

### Через AWS Console

1. Перейти в **VPC** → **Your VPCs** — має з'явитися `goit-vpc-mds`
2. **Subnets** — два сабнети `goit-vpc-mds-public-subnet` та `goit-vpc-mds-private-subnet`
3. **Route tables** — у публічної є маршрут `0.0.0.0/0` на `igw-...`, у приватної — лише `local`
4. **Security groups** та **Network ACLs** — по дві з префіксом `goit-vpc-mds`

### Через AWS CLI

```bash
aws ec2 describe-vpcs \
  --profile goit-aws-mds \
  --filters "Name=tag:Name,Values=goit-vpc-mds" \
  --query "Vpcs[].{VpcId:VpcId,CIDR:CidrBlock}" \
  --output table
```

### Через Terraform

```bash
terraform output
```

---

## Крок 5: Створення EC2 у готовій мережі

Усі необхідні ID вже в outputs:

```bash
terraform output public_subnet_id            # сабнет для публічної EC2
terraform output public_security_group_id    # security group для публічної EC2
terraform output private_subnet_id           # сабнет для приватної EC2
terraform output private_security_group_id   # security group для приватної EC2
```

### 5.1 Через AWS Console

1. Перейти в **EC2** → **Launch instance**
2. Name: `goit-public-ec2`, AMI: **Amazon Linux 2023**, Instance type: **t2.micro** (free tier)
3. Key pair: обрати наявну або створити нову
4. У блоці **Network settings** натиснути **Edit**:
   - VPC: `goit-vpc-mds`
   - Subnet: `goit-vpc-mds-public-subnet`
   - Auto-assign public IP: **Enable** (вже увімкнено на рівні сабнету)
   - Firewall: **Select existing security group** → `goit-vpc-mds-public-sg`
5. Натиснути **Launch instance**

Для приватної EC2 — те саме, але Subnet: `goit-vpc-mds-private-subnet`, security group: `goit-vpc-mds-private-sg` (публічної IP не буде — це очікувано).

### 5.2 Через AWS CLI

```bash
# Публічна EC2
aws ec2 run-instances \
  --profile goit-aws-mds \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t2.micro \
  --key-name <ІМ'Я_ВАШОГО_KEY_PAIR> \
  --subnet-id $(terraform output -raw public_subnet_id) \
  --security-group-ids $(terraform output -raw public_security_group_id) \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=goit-public-ec2}]'

# Приватна EC2
aws ec2 run-instances \
  --profile goit-aws-mds \
  --image-id resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --instance-type t2.micro \
  --key-name <ІМ'Я_ВАШОГО_KEY_PAIR> \
  --subnet-id $(terraform output -raw private_subnet_id) \
  --security-group-ids $(terraform output -raw private_security_group_id) \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=goit-private-ec2}]'
```

### 5.3 Перевірка ізоляції (опційно)

1. Підключитися по SSH до публічної EC2: `ssh -i key.pem ec2-user@<PUBLIC_IP>`
2. З неї пропінгувати приватну: `ping <PRIVATE_IP_приватної_EC2>` — працює (трафік усередині VPC дозволено)
3. Спробувати з публічної EC2 в інтернет: `curl https://google.com` — працює
4. Приватна EC2 ззовні недоступна, і сама в інтернет не виходить — у неї немає ні публічної IP, ні маршруту через IGW

---

## Крок 6: Видалення ресурсів

> **Важливо:** спочатку видалити (terminate) усі EC2, створені вручну в цій VPC, інакше `destroy` завершиться помилкою `DependencyViolation`.

```bash
terraform destroy
```

Ввести `yes` для підтвердження. Очікуваний результат: `Destroy complete! Resources: 12 destroyed.`

---

## Довідка: публічний vs приватний сабнет

| | Публічний | Приватний |
|---|---|---|
| Публічна IP у EC2 | Так, автоматично | Ні |
| Маршрут в інтернет | `0.0.0.0/0 → IGW` | Відсутній |
| Доступ ззовні | SSH/HTTP/HTTPS (через SG) | Неможливий |
| Доступ зсередини VPC | Так | Так (лише від публічної SG) |
| Типове використання | Веб-сервери, bastion-хости | Бази даних, внутрішні сервіси |

**Security Group vs Network ACL:**

| | Security Group | Network ACL |
|---|---|---|
| Рівень | Мережевий інтерфейс EC2 | Сабнет |
| Тип | Stateful — відповідь дозволена автоматично | Stateless — відповідь треба дозволяти окремо |
| Правила | Лише allow | Allow і deny, з номерами пріоритету |
| Навіщо обидва | Точковий контроль на інстансі | Додатковий бар'єр на весь сабнет |
