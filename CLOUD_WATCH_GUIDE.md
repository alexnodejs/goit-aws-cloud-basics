# CloudWatch Agent на EC2 — Покрокова інструкція

## Мета

Створити EC2 інстанс з встановленим CloudWatch Agent, який збирає метрики (CPU, Memory, Disk) та відправляє їх у CloudWatch.

## Передумови

- AWS акаунт з доступом до консолі або CLI
- Встановлений AWS CLI (`aws --version`)
- Налаштований профіль (`aws configure`)
- Регіон: `eu-central-1` (Frankfurt)

---

## Крок 1: Створити IAM Role для EC2

EC2 інстанс потребує дозволів для відправки метрик у CloudWatch. Для цього створюємо IAM Role.

### 1.1 Через AWS Console

1. Перейти в **IAM** → **Roles** → **Create role**
2. Trusted entity type: **AWS service**
3. Use case: **EC2**
4. Натиснути **Next**
5. У пошуку знайти та обрати політику **CloudWatchAgentServerPolicy**
6. Натиснути **Next**
7. Role name: `pizz-cloud-watch-ec2-role`
8. Натиснути **Create role**

### 1.2 Через AWS CLI

```bash
# Створити роль з довірчою політикою для EC2
aws iam create-role \
  --role-name pizz-cloud-watch-ec2-role \
  --assume-role-policy-document '{
    "Version":"2012-10-17",
    "Statement":[{
      "Effect":"Allow",
      "Principal":{"Service":"ec2.amazonaws.com"},
      "Action":"sts:AssumeRole"
    }]
  }'

# Прикріпити політику CloudWatch Agent
aws iam attach-role-policy \
  --role-name pizz-cloud-watch-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

# Створити Instance Profile (потрібен для прив'язки ролі до EC2)
aws iam create-instance-profile \
  --instance-profile-name pizz-cloud-watch-ec2-profile

# Додати роль до Instance Profile
aws iam add-role-to-instance-profile \
  --instance-profile-name pizz-cloud-watch-ec2-profile \
  --role-name pizz-cloud-watch-ec2-role
```

> **Що таке Instance Profile?**
> EC2 не може використовувати IAM Role напряму. Instance Profile — це "обгортка", яка зв'язує роль з інстансом.

---

## Крок 2: Створити Security Group

Security Group контролює мережевий доступ до інстансу. Нам потрібен SSH (порт 22) для підключення.

### 2.1 Через AWS Console

1. Перейти в **EC2** → **Security Groups** → **Create security group**
2. Name: `pizz-cloud-watch-sg`
3. Description: `SG for pizz-cloud-watch-ec2`
4. VPC: обрати default VPC
5. Inbound rules → **Add rule**:
   - Type: **SSH**
   - Source: **My IP** (або `0.0.0.0/0` для доступу звідусіль)
6. Натиснути **Create security group**

### 2.2 Через AWS CLI

```bash
# Створити Security Group
aws ec2 create-security-group \
  --group-name pizz-cloud-watch-sg \
  --description "SG for pizz-cloud-watch-ec2" \
  --vpc-id <YOUR_VPC_ID>

# Відкрити SSH (порт 22)
aws ec2 authorize-security-group-ingress \
  --group-id <SG_ID> \
  --protocol tcp --port 22 --cidr 0.0.0.0/0
```

> **Як дізнатися VPC ID?**
> ```bash
> aws ec2 describe-vpcs --query 'Vpcs[?IsDefault].VpcId' --output text
> ```

---

## Крок 3: Створити User Data скрипт

User Data — це скрипт, який автоматично виконується при першому запуску інстансу. Він встановить та налаштує CloudWatch Agent.

Створити файл `user-data.sh`:

```bash
#!/bin/bash
# 1. Встановити CloudWatch Agent
yum install -y amazon-cloudwatch-agent

# 2. Створити конфігурацію агента
cat <<'CWCONFIG' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "CWAgent",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "totalcpu": true
      },
      "mem": {
        "measurement": ["mem_used_percent", "mem_available_percent"]
      },
      "disk": {
        "measurement": ["used_percent", "free"],
        "resources": ["*"]
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "InstanceType": "${aws:InstanceType}"
    }
  }
}
CWCONFIG

# 3. Запустити агент з конфігурацією
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s
```

### Що збирає конфігурація:

| Метрика | Опис |
|---------|------|
| `cpu_usage_idle` | % часу CPU у стані очікування |
| `cpu_usage_user` | % часу CPU на користувацькі процеси |
| `cpu_usage_system` | % часу CPU на системні процеси |
| `mem_used_percent` | % використаної пам'яті |
| `mem_available_percent` | % доступної пам'яті |
| `disk used_percent` | % використаного місця на диску |
| `disk free` | Вільне місце на диску (байти) |

> **Важливо:** `append_dimensions` додає InstanceId та InstanceType до кожної метрики, щоб можна було фільтрувати у CloudWatch по конкретному інстансу.

---

## Крок 4: Запустити EC2 інстанс

### 4.1 Через AWS Console

1. Перейти в **EC2** → **Launch Instance**
2. Name: `pizz-cloud-watch-ec2`
3. AMI: **Amazon Linux 2023** (безкоштовний)
4. Instance type: **t3.micro**
5. Key pair: обрати існуючий або створити новий
6. Network settings → обрати створений Security Group (`pizz-cloud-watch-sg`)
7. Advanced details:
   - IAM instance profile: `pizz-cloud-watch-ec2-profile`
   - User data: вставити вміст файлу `user-data.sh`
8. Натиснути **Launch instance**

### 4.2 Через AWS CLI

```bash
aws ec2 run-instances \
  --image-id ami-0cf4768e2f1e520c5 \
  --instance-type t3.micro \
  --key-name <YOUR_KEY_NAME> \
  --security-group-ids <SG_ID> \
  --iam-instance-profile Name=pizz-cloud-watch-ec2-profile \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=pizz-cloud-watch-ec2}]' \
  --user-data file://user-data.sh
```

> **Як знайти AMI ID для Amazon Linux 2023?**
> ```bash
> aws ec2 describe-images --owners amazon \
>   --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" \
>   --query 'sort_by(Images, &CreationDate)[-1].{ID:ImageId,Name:Name}' \
>   --output table
> ```

---

## Крок 5: Перевірити результат

Зачекайте **5 хвилин** після запуску інстансу — агенту потрібен час на встановлення та відправку перших метрик.

### 5.1 Перевірити що інстанс працює

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=pizz-cloud-watch-ec2" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,ID:InstanceId,State:State.Name,PublicIP:PublicIpAddress}' \
  --output table
```

### 5.2 Перевірити метрики CWAgent через CLI

```bash
aws cloudwatch list-metrics --namespace CWAgent
```

Якщо все працює, ви побачите список метрик з namespace `CWAgent`.

### 5.3 Перевірити через AWS Console

1. Перейти в **CloudWatch** → **Metrics** → **All metrics**
2. Знайти namespace **CWAgent**
3. Обрати метрики по InstanceId
4. Ви побачите графіки CPU, Memory та Disk

### 5.4 (Опціонально) SSH на інстанс для перевірки агента

```bash
ssh -i <your-key.pem> ec2-user@<PUBLIC_IP>

# Перевірити статус агента
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

Очікуваний результат:
```json
{
  "status": "running",
  "starttime": "...",
  "configstatus": "configured",
  "cwoc_status": "stopped",
  "version": "..."
}
```

---

## Усунення проблем

### Метрики не з'являються у CloudWatch

1. **Перевірте IAM Role** — інстанс повинен мати Instance Profile з політикою `CloudWatchAgentServerPolicy`
2. **Перевірте статус агента** через SSH (див. крок 5.4)
3. **Перевірте логи агента:**
   ```bash
   sudo cat /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
   ```
4. **Перевірте User Data логи** (чи виконався скрипт):
   ```bash
   sudo cat /var/log/cloud-init-output.log
   ```

### Не вдається підключитися по SSH

1. Перевірте що Security Group має правило для порту 22
2. Перевірте що використовуєте правильний ключ (.pem файл)
3. Перевірте що інстанс має Public IP

---

## Очищення ресурсів

Щоб не платити за ресурси після завершення роботи:

```bash
# 1. Зупинити/видалити інстанс
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>

# 2. Видалити Security Group (після видалення інстансу)
aws ec2 delete-security-group --group-id <SG_ID>

# 3. Видалити IAM ресурси
aws iam remove-role-from-instance-profile \
  --instance-profile-name pizz-cloud-watch-ec2-profile \
  --role-name pizz-cloud-watch-ec2-role

aws iam delete-instance-profile \
  --instance-profile-name pizz-cloud-watch-ec2-profile

aws iam detach-role-policy \
  --role-name pizz-cloud-watch-ec2-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

aws iam delete-role --role-name pizz-cloud-watch-ec2-role
```
