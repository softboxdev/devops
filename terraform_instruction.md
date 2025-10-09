# Создание Terraform проекта для Yandex Cloud (учебные цели)

## 🎯 Предварительные требования

### 1. Регистрация в Yandex Cloud
- Аккаунт в Yandex (яндекс почта)
- Активированный пробный период (до 4000 ₽ на 60 дней)
- Созданное облако и каталог

### 2. Установка инструментов
```bash
# Установка Terraform
sudo apt update
sudo apt install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt update && sudo apt install terraform

# Проверка установки
terraform version

# Установка Yandex Cloud CLI (опционально)
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
source ~/.bashrc
```

---

## 🔐 Настройка доступа к Yandex Cloud

### Шаг 1: Создание сервисного аккаунта

1. Перейдите в [Yandex Cloud Console](https://console.cloud.yandex.ru)
2. Выберите ваш каталог
3. Перейдите в "Сервисные аккаунты" → "Создать аккаунт"
4. Заполните:
   - **Имя**: `terraform-sa`
   - **Описание**: `Service account for Terraform`
   - **Роли**: `editor`, `vpc.publicAdmin`, `storage.admin`

### Шаг 2: Создание авторизованного ключа

```bash
# Создание ключа через CLI (если установлен yc)
yc iam key create --service-account-name terraform-sa --output key.json

# Или через консоль:
# 1. Сервисные аккаунты → terraform-sa → "Создать новый ключ"
# 2. Выберите "JSON"
# 3. Скачайте файл key.json
```

### Шаг 3: Получение идентификаторов

```bash
# Получение cloud_id
yc config get cloud-id

# Получение folder_id
yc config get folder-id

# Или через консоль:
# Cloud ID: На главной странице консоли под названием облака
# Folder ID: В настройках каталога
```

---

## 🏗️ Создание структуры Terraform проекта

### Структура проекта:
```
yandex-cloud-terraform/
├── providers.tf
├── variables.tf
├── terraform.tfvars
├── main.tf
├── outputs.tf
├── network.tf
├── compute.tf
├── storage.tf
└── scripts/
    └── user-data.sh
```

### Шаг 1: Настройка провайдера

```hcl
# providers.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.89"
    }
  }

  # Опционально: хранение state в Yandex Object Storage
  backend "s3" {
    endpoint   = "storage.yandexcloud.net"
    bucket     = "my-terraform-state"
    key        = "terraform.tfstate"
    region     = "ru-central1"
    access_key = "YCAJ...=="
    secret_key = "YCP...=="

    skip_region_validation      = true
    skip_credentials_validation = true
  }
}

# Настройка провайдера Yandex Cloud
provider "yandex" {
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
  
  # Укажите один из способов аутентификации:
  
  # Способ 1: Через сервисный аккаунт (рекомендуется)
  service_account_key_file = var.yc_service_account_key_file
  
  # Способ 2: Через OAuth токен
  # token = var.yc_token
}
```

### Шаг 2: Определение переменных

```hcl
# variables.tf

# Обязательные переменные
variable "yc_cloud_id" {
  description = "Yandex Cloud Cloud ID"
  type        = string
  sensitive   = true
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
  sensitive   = true
}

variable "yc_service_account_key_file" {
  description = "Path to Yandex Cloud service account key file"
  type        = string
  default     = "key.json"
}

# Конфигурационные переменные
variable "yc_zone" {
  description = "Yandex Cloud default zone"
  type        = string
  default     = "ru-central1-a"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "learn-terraform"
}

# Переменные для ВМ
variable "vm_count" {
  description = "Number of VM instances to create"
  type        = number
  default     = 1
}

variable "vm_image_id" {
  description = "Image ID for VM instances"
  type        = string
  default     = "fd87va5cc00gaq2f5qfb" # Ubuntu 22.04
}

variable "vm_platform_id" {
  description = "Platform ID for VM instances"
  type        = string
  default     = "standard-v3"
}

variable "vm_username" {
  description = "Username for VM access"
  type        = string
  default     = "ubuntu"
}

# Переменные для сети
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}
```

### Шаг 3: Значения переменных

```hcl
# terraform.tfvars
yc_cloud_id  = "b1gxxxxxxxxxxxxxxxxxxx"
yc_folder_id = "b1gxxxxxxxxxxxxxxxxxxx"

# Для продакшена используйте:
environment = "dev"
vm_count    = 1
project_name = "terraform-learning"
```

### Создайте файл с чувствительными данными (в .gitignore):
```bash
# secrets.auto.tfvars (добавьте в .gitignore!)
yc_cloud_id  = "your_cloud_id_here"
yc_folder_id = "your_folder_id_here"
```

---

## 🌐 Создание сетевой инфраструктуры

```hcl
# network.tf

# Создание VPC
resource "yandex_vpc_network" "main" {
  name        = "${var.project_name}-network"
  description = "Main network for ${var.project_name} project"
  
  labels = {
    environment = var.environment
    project     = var.project_name
    managed-by  = "terraform"
  }
}

# Создание подсетей
resource "yandex_vpc_subnet" "subnets" {
  count = length(var.subnet_cidrs)
  
  name           = "${var.project_name}-subnet-${count.index + 1}"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_cidrs[count.index]]
  
  labels = {
    environment = var.environment
    project     = var.project_name
    subnet-type = count.index == 0 ? "public" : "private"
  }
}

# Security Group для веб-серверов
resource "yandex_vpc_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for web servers"
  network_id  = yandex_vpc_network.main.id

  labels = {
    environment = var.environment
    project     = var.project_name
  }

  ingress {
    description    = "HTTP"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "HTTPS"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description    = "SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Outgoing traffic"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## 💻 Создание виртуальных машин

```hcl
# compute.tf

# Создание сервисного аккаунта для ВМ
resource "yandex_iam_service_account" "vm" {
  name        = "${var.project_name}-vm-sa"
  description = "Service account for VM instances"
  
  labels = {
    environment = var.environment
    project     = var.project_name
  }
}

# Назначение ролей сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "vm_roles" {
  for_each = toset([
    "editor",
    "storage.editor"
  ])
  
  folder_id = var.yc_folder_id
  role      = each.key
  member    = "serviceAccount:${yandex_iam_service_account.vm.id}"
}

# Создание SSH ключа
resource "yandex_compute_instance" "vm" {
  count = var.vm_count
  
  name        = "${var.project_name}-vm-${count.index + 1}"
  platform_id = var.vm_platform_id
  zone        = var.yc_zone

  resources {
    cores  = 2
    memory = 2
    core_fraction = 20 # 20% гарантии vCPU
  }

  boot_disk {
    initialize_params {
      image_id = var.vm_image_id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnets[0].id # Используем первую подсеть
    nat       = true # Включить внешний IP
    security_group_ids = [yandex_vpc_security_group.web.id]
  }

  metadata = {
    ssh-keys = "${var.vm_username}:${file("~/.ssh/id_rsa.pub")}"
    user-data = file("${path.module}/scripts/user-data.sh")
  }

  service_account_id = yandex_iam_service_account.vm.id

  scheduling_policy {
    preemptible = true # Использовать прерываемые ВМ для экономии
  }

  labels = {
    environment = var.environment
    project     = var.project_name
    role        = "web-server"
  }

  # Жизненный цикл - игнорировать изменения SSH ключей
  lifecycle {
    ignore_changes = [metadata]
  }
}

# Создание статического IP адреса
resource "yandex_vpc_address" "static_ip" {
  count = var.vm_count
  
  name = "${var.project_name}-ip-${count.index + 1}"

  external_ipv4_address {
    zone_id = var.yc_zone
  }

  labels = {
    environment = var.environment
    project     = var.project_name
  }
}

# Привязка статического IP к ВМ
resource "yandex_compute_instance_address_assignment" "vm_ip" {
  count = var.vm_count
  
  instance_id   = yandex_compute_instance.vm[count.index].id
  address_index = 0
  external_ipv4_address {
    address = yandex_vpc_address.static_ip[count.index].external_ipv4_address[0].address
  }
}
```

---

## 💾 Создание хранилища

```hcl
# storage.tf

# Создание бакета Object Storage
resource "yandex_storage_bucket" "data" {
  bucket = "${var.project_name}-data-${var.environment}"
  
  access_key = yandex_iam_service_account_static_access_key.s3.keys[0].access_key
  secret_key = yandex_iam_service_account_static_access_key.s3.keys[0].secret_key

  anonymous_access_flags {
    read = false
    list = false
  }

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    project     = var.project_name
  }
}

# Создание статических ключей доступа для S3
resource "yandex_iam_service_account_static_access_key" "s3" {
  service_account_id = yandex_iam_service_account.vm.id
  description        = "Static access key for S3"
}
```

---

## 📜 User Data скрипт для инициализации ВМ

```bash
#!/bin/bash
# scripts/user-data.sh

# Update system
apt-get update
apt-get upgrade -y

# Install necessary packages
apt-get install -y \
    nginx \
    curl \
    htop \
    tree

# Create web directory
mkdir -p /var/www/html

# Create simple HTML page
cat > /var/www/html/index.html << EOF
<html>
<head>
    <title>Welcome to ${HOSTNAME}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .info { background: #f4f4f4; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Terraform Learning Project</h1>
        <div class="info">
            <h2>Server Information:</h2>
            <p><strong>Hostname:</strong> $(hostname)</p>
            <p><strong>IP Address:</strong> $(hostname -I | awk '{print $1}')</p>
            <p><strong>Zone:</strong> ru-central1-a</p>
            <p><strong>Managed by:</strong> Terraform</p>
        </div>
        <h3>Next Steps:</h3>
        <ul>
            <li>Connect via SSH: ssh ubuntu@$(curl -s ifconfig.me)</li>
            <li>Check nginx status: systemctl status nginx</li>
            <li>View logs: journalctl -u nginx -f</li>
        </ul>
    </div>
</body>
</html>
EOF

# Configure nginx to serve our page
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Start and enable nginx
systemctl enable nginx
systemctl start nginx

# Create info script
cat > /usr/local/bin/server-info << 'EOF'
#!/bin/bash
echo "=== Server Information ==="
echo "Hostname: $(hostname)"
echo "IP: $(hostname -I | awk '{print $1}')"
echo "Uptime: $(uptime -p)"
echo "Disk: $(df -h / | awk 'NR==2 {print $4 " free"}')"
echo "Memory: $(free -h | awk 'NR==2 {print $4 " free"}')"
echo "=========================="
EOF

chmod +x /usr/local/bin/server-info

# Log completion
echo "User-data script completed at $(date)" >> /var/log/user-data.log
```

---

## 📤 Output значения

```hcl
# outputs.tf

output "vpc_network_id" {
  description = "ID of the created VPC network"
  value       = yandex_vpc_network.main.id
}

output "vm_public_ips" {
  description = "Public IP addresses of VM instances"
  value       = yandex_compute_instance.vm[*].network_interface[0].nat_ip_address
}

output "vm_private_ips" {
  description = "Private IP addresses of VM instances"
  value       = yandex_compute_instance.vm[*].network_interface[0].ip_address
}

output "ssh_connection_commands" {
  description = "SSH connection commands"
  value = [
    for i, ip in yandex_compute_instance.vm[*].network_interface[0].nat_ip_address :
    "ssh ${var.vm_username}@${ip}"
  ]
}

output "web_urls" {
  description = "URLs to access web servers"
  value = [
    for ip in yandex_compute_instance.vm[*].network_interface[0].nat_ip_address :
    "http://${ip}"
  ]
}

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = yandex_storage_bucket.data.bucket
}

output "security_group_id" {
  description = "ID of the web security group"
  value       = yandex_vpc_security_group.web.id
}
```

---

## 🚀 Развертывание инфраструктуры

### Шаг 1: Инициализация проекта

```bash
# Создание директории проекта
mkdir yandex-cloud-terraform
cd yandex-cloud-terraform

# Создание файлов конфигурации
# (скопируйте содержимое выше в соответствующие файлы)

# Создание SSH ключа (если нет)
ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/id_rsa -N ""

# Инициализация Terraform
terraform init
```

### Шаг 2: Планирование развертывания

```bash
# Проверка синтаксиса
terraform validate

# Форматирование кода
terraform fmt

# Просмотр плана развертывания
terraform plan

# План с сохранением в файл
terraform plan -out=plan.tfplan
```

### Шаг 3: Применение конфигурации

```bash
# Применение с подтверждением
terraform apply

# Или применение без подтверждения
terraform apply -auto-approve

# Применение из файла плана
terraform apply plan.tfplan
```

### Шаг 4: Проверка развертывания

```bash
# Просмотр output значений
terraform output

# Просмотр созданных ресурсов
terraform show

# Проверка состояния
terraform state list
```

### Шаг 5: Тестирование

```bash
# Получение IP адресов ВМ
terraform output vm_public_ips

# Тестирование веб-сервера
curl http://<vm-public-ip>

# Подключение по SSH
ssh ubuntu@<vm-public-ip>
```

---

## 🛠️ Управление инфраструктурой

### Полезные команды:

```bash
# Просмотр конкретного ресурса
terraform state show yandex_compute_instance.vm[0]

# Импорт существующего ресурса
terraform import yandex_compute_instance.existing_vm <instance-id>

# Обновление state
terraform refresh

# Создание графа зависимостей
terraform graph | dot -Tpng > graph.png

# Уничтожение инфраструктуры
terraform destroy
```

### Автоматизация с Makefile:

```makefile
.PHONY: init plan apply destroy validate ssh

init:
	terraform init

validate:
	terraform validate

plan:
	terraform plan -out=plan.tfplan

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

ssh:
	ssh ubuntu@$$(terraform output -raw vm_public_ips | tr -d '[]"' | cut -d',' -f1)

output:
	terraform output

fmt:
	terraform fmt -recursive

clean:
	rm -rf .terraform* terraform.tfstate* plan.tfplan
```

---

## 💰 Контроль расходов

### Бюджетные настройки:

```hcl
# budget.tf (опционально)

resource "yandex_billing_cloud_budget" "monthly_budget" {
  name        = "terraform-learning-budget"
  amount      = 1000 # 1000 рублей
  threshold   = 80   # Уведомление при 80% использования
  
  filter {
    cloud_id = var.yc_cloud_id
  }
  
  notification {
    threshold_percent = 80
    recipients       = ["your-email@example.com"]
  }
}
```

### Экономия средств:
- Используйте **preemptible** ВМ (на 50% дешевле)
- Выбирайте **core_fraction = 5 или 20** для ненагруженных ВМ
- Используйте **network-hdd** для некритичных данных
- Регулярно запускайте `terraform destroy`

---

## 🎯 Учебные задания

### Задание 1: Базовое развертывание
1. Разверните одну ВМ с nginx
2. Настройте security group
3. Проверьте доступность веб-сервера

### Задание 2: Масштабирование
1. Увеличьте количество ВМ до 2
2. Настройте балансировщик нагрузки
3. Протестируйте отказоустойчивость

### Задание 3: Хранилище
1. Создайте и примонтируйте диск к ВМ
2. Настройте бакет Object Storage
3. Протестируйте загрузку файлов

### Задание 4: Мониторинг
1. Настройте Yandex Monitoring
2. Создайте дашборд для отслеживания метрик
3. Настройте алерты

---

## 🔐 Безопасность

### Рекомендации по безопасности:
```bash
# Добавьте в .gitignore
echo "*.tfvars" >> .gitignore
echo "*.auto.tfvars" >> .gitignore  
echo "key.json" >> .gitignore
echo ".terraform*" >> .gitignore
echo "terraform.tfstate*" >> .gitignore
```

### Использование Yandex Lockbox для секретов:
```hcl
# lockbox.tf (для продакшена)
data "yandex_lockbox_secret" "db_password" {
  name = "database-password"
}

resource "yandex_lockbox_secret_version" "db" {
  secret_id = data.yandex_lockbox_secret.db_password.id
  entries {
    key        = "password"
    text_value = var.db_password
  }
}
```

Эта инструкция позволит вам создать полнофункциональную учебную инфраструктуру в Yandex Cloud с использованием Terraform! 🚀