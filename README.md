# goit-aws-cloud-basics

Навчальний проєкт GoIT (модуль MDS): інфраструктура в **AWS** як код за допомогою
**Terraform**. Одним `terraform apply` створюється:

1. **Мережа** — VPC `goit-vpc-mds` (`10.0.0.0/16`) з публічними та приватним
   сабнетами, Internet Gateway, таблицями маршрутизації, Security Groups та NACL.
2. **Балансування та автоскейлінг** — **Application Load Balancer** + **Target
   Group** + **Auto Scaling Group** з двома EC2 `t3.small`, на яких при старті
   автоматично встановлюється **nginx** і піднімається сторінка
   `MDS GOIT Load Balancer`.

---

## 📁 Структура репозиторію

```
goit-aws-cloud-basics/
├── README.md
└── terraform-ec2-alb-asg/
    ├── providers.tf      # AWS-провайдер: профіль + регіон + default_tags
    ├── versions.tf       # вимоги до версій Terraform та провайдера
    ├── variables.tf      # 👈 УСІ параметри для зміни (профіль, регіон, CIDR, тип EC2…)
    ├── main.tf           # VPC, сабнети, Internet Gateway, route tables
    ├── security.tf       # Security Groups + Network ACL
    ├── alb.tf            # Target Group, Application Load Balancer, listener
    ├── compute.tf        # AMI (Amazon Linux 2023), Launch Template (nginx), Auto Scaling Group
    └── outputs.tf        # виводи: DNS балансувальника, ID ресурсів
```

---

## 🏗 Що буде створено

```
        Інтернет
           │  HTTP :80
           ▼
   ┌─────────────────────┐
   │  Application LB      │  goit-mds-alb  (у 2 публічних сабнетах / 2 AZ)
   │  goit-vpc-mds-alb-sg │
   └──────────┬──────────┘
              │ forward → Target Group (goit-mds-tg)
       ┌──────┴───────┐
       ▼              ▼
  ┌─────────┐    ┌─────────┐
  │  EC2 #  │    │  EC2 #  │   t3.small, nginx, Auto Scaling Group
  │ goit-   │    │ goit-   │   goit-mds-asg (min=2, max=2, desired=2)
  │ mds-ec2 │    │ mds-ec2 │   у публічних сабнетах AZ-a та AZ-b
  └─────────┘    └─────────┘
```

| Ресурс | Назва | Призначення |
|---|---|---|
| VPC | `goit-vpc-mds` | Мережа `10.0.0.0/16` |
| Subnet (public A/B) | `goit-vpc-mds-public-subnet`, `...-public-subnet-b` | EC2 + ALB у двох AZ |
| Subnet (private) | `goit-vpc-mds-private-subnet` | Ізольований сабнет без виходу в інтернет |
| Application Load Balancer | `goit-mds-alb` | Приймає HTTP з інтернету, балансує між EC2 |
| Target Group | `goit-mds-tg` | Група цілей з health-check `/` |
| Launch Template | `goit-mds-ec2-*` | Шаблон EC2: AL2023 + nginx через user_data |
| Auto Scaling Group | `goit-mds-asg` | Тримає **рівно 2** інстанси `goit-mds-ec2` |
| Security Group (ALB) | `goit-vpc-mds-alb-sg` | HTTP 80 з інтернету |
| Security Group (web) | `goit-vpc-mds-web-sg` | HTTP 80 **лише від ALB** + SSH |

> Чому сторінки не «#1» і «#2», а з `instance-id`? Auto Scaling Group запускає
> однакові інстанси з одного шаблону. Щоб довести, що балансування працює,
> кожен інстанс показує **свій** `instance-id` / `hostname` / зону — оновлюючи
> сторінку через ALB, ви бачите, що відповідають різні інстанси.

---

## ✅ Передумови

- AWS-акаунт з правами на VPC / EC2 / ELB / Auto Scaling
- **AWS CLI** — `aws --version`
- **Terraform >= 1.5** — `terraform version`
  - macOS: `brew install terraform`
  - Windows: `choco install terraform` або [developer.hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install)

---

## ⚙️ Що змінити перед запуском (важливо!)

**Усі параметри лежать в одному файлі — [`terraform-ec2-alb-asg/variables.tf`](terraform-ec2-alb-asg/variables.tf).**
Нічого більше міняти не обовʼязково: усі змінні мають значення за замовчуванням.

| Що | Змінна / файл | За замовчуванням | Коли міняти |
|---|---|---|---|
| **AWS-профіль** | `aws_profile` у `variables.tf` | `goit-aws-mds` | Якщо ваш профіль називається інакше |
| **Регіон** | `aws_region` у `variables.tf` | `eu-central-1` | Якщо працюєте в іншому регіоні |
| **SSH-доступ** | `ssh_allowed_cidr` у `variables.tf` | `0.0.0.0/0` | Бажано звузити до своєї IP |
| **Тип EC2** | `instance_type` у `variables.tf` | `t3.small` | Якщо потрібен інший розмір |
| **SSH-ключ** | `key_name` у `variables.tf` | `null` (без ключа) | Вкажіть назву наявної EC2 key pair |
| CIDR-блоки | `vpc_cidr`, `*_subnet_cidr` у `variables.tf` | `10.0.x.0/...` | Зазвичай не потрібно |

### 1. Налаштувати AWS-профіль

Цей проєкт автентифікується через **іменований профіль AWS CLI** (`providers.tf`
→ `profile = var.aws_profile`). Найпростіше — створити профіль з тією ж назвою,
що й за замовчуванням:

```bash
aws configure --profile goit-aws-mds
# Access Key ID, Secret Access Key, регіон eu-central-1, формат json
```

Перевірити, що профіль працює:

```bash
aws sts get-caller-identity --profile goit-aws-mds
```

> **Якщо ваш профіль має іншу назву** — не редагуйте код, просто передайте її при запуску:
> ```bash
> terraform apply -var="aws_profile=НАЗВА_ВАШОГО_ПРОФІЛЮ"
> ```
> або відредагуйте `default` змінної `aws_profile` у `terraform-ec2-alb-asg/variables.tf`.

### 2. (Опційно) Винести свої значення у `terraform.tfvars`

Замість правок у `variables.tf` можна створити файл `terraform-ec2-alb-asg/terraform.tfvars`
(він **у `.gitignore`**, тож у репозиторій не потрапить):

```hcl
aws_profile      = "my-aws-profile"
aws_region       = "eu-central-1"
ssh_allowed_cidr = "203.0.113.10/32"
key_name         = "my-ec2-keypair"
```

---

## 🚀 Запуск

```bash
cd terraform-ec2-alb-asg

terraform init      # завантажити провайдер AWS
terraform plan      # подивитися, що буде створено (~21 ресурс)
terraform apply     # створити (ввести yes для підтвердження)
```

Корисно одразу обмежити SSH до своєї IP:

```bash
terraform apply -var="ssh_allowed_cidr=$(curl -s ifconfig.me)/32"
```

---

## 🔎 Перевірка результату

```bash
terraform output alb_dns_name      # DNS-імʼя балансувальника
```

1. Відкрийте `http://<alb_dns_name>` у браузері (HTTP, не HTTPS).
2. Кілька разів оновіть сторінку — заголовок `MDS GOIT Load Balancer`
   лишається, а `Instance` / `Host` / `AZ` **змінюються** → балансування працює.
3. У консолі **EC2 → Auto Scaling Groups** має бути `goit-mds-asg` з 2 інстансами,
   а в **Target Groups → goit-mds-tg** — 2 healthy targets.
4. (Опційно) Завершіть один інстанс вручну — ASG автоматично підніме новий,
   щоб знову було 2.

> ⏳ Після `apply` дайте ~2–3 хвилини: інстансам потрібен час встановити nginx,
> а ALB — перевести цілі у стан `healthy`.

---

## 🧹 Видалення ресурсів

Щоб не платити за ALB та EC2, після перевірки видаліть усе:

```bash
cd terraform-ec2-alb-asg
terraform destroy   # ввести yes
```

---

> ⚠️ Ресурси ALB, EC2 та трафік **тарифікуються** AWS. Це навчальний проєкт —
> не залишайте інфраструктуру піднятою без потреби, видаляйте через `terraform destroy`.
