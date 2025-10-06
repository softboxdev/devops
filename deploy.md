Отличный вопрос! Настроить GitHub Actions для деплоя на бесплатный сервер — это мощный способ автоматизировать ваши процессы. Вот подробное руководство.

## **Бесплатные варианты серверов для деплоя**

### **1. VPS-провайдеры с бесплатным тарифом**

**Oracle Cloud Free Tier**
- **Самое выгодное предложение:** 2 виртуальные машины с 1 ГБ RAM каждая + 4 ARM-ядра + 24 ГБ RAM (всегда бесплатно)
- **Как использовать:** Создайте VM и настройте деплой через SSH

**AWS Free Tier**
- **EC2:** 750 часов в месяц t2.micro или t3.micro в течение 12 месяцев
- **Lightsail:** 3 месяца бесплатно

**Google Cloud Platform**
- **$300 кредита** на 90 дней
- **Always Free:** f1-micro instance в одном регионе

**Azure**
- **$200 кредита** на 30 дней
- **Always Free:** 750 часов B1S виртуальной машины

### **2. Бесплатные хостинги для приложений**

- **Heroku** (с ограничениями на бесплатном тарифе)
- **Railway**
- **Render**
- **Fly.io**

---

## **Настройка GitHub Actions для деплоя на VPS через SSH**

Рассмотрим самый универсальный вариант — деплой на ваш собственный VPS (например, от Oracle Cloud).

### **Шаг 1: Подготовка сервера**

1. **Создайте виртуальную машину** у выбранного провайдера
2. **Настройте базовое окружение:**
```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker (опционально, но рекомендуется)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Установка Node.js (пример для веб-приложения)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Установка nginx
sudo apt install nginx -y
```

### **Шаг 2: Создание SSH-ключа для GitHub Actions**

1. **Сгенерируйте специальный SSH-ключ:**
```bash
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github-actions
```

2. **Добавьте публичный ключ на сервер:**
```bash
# На сервере
echo "ВАШ_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

3. **Настройте SSH на сервере** (опционально, для безопасности):
```bash
# /etc/ssh/sshd_config
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
```

### **Шаг 3: Настройка секретов в GitHub Repository**

1. **В вашем репозитории GitHub перейдите:**
   `Settings → Secrets and variables → Actions`

2. **Добавьте следующие секреты:**
   - `SERVER_IP` - IP-адрес вашего сервера
   - `SSH_PRIVATE_KEY` - содержимое приватного SSH-ключа
   - `SSH_USERNAME` - имя пользователя на сервере (обычно `ubuntu` или `root`)

### **Шаг 4: Создание workflow файла**

Создайте файл в вашем репозитории: `.github/workflows/deploy.yml`

```yaml
name: Deploy to VPS

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '18'
        
    - name: Install dependencies
      run: npm install
      
    - name: Run tests
      run: npm test

  deploy:
    runs-on: ubuntu-latest
    needs: test  # Запускаем деплой только если тесты прошли
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup SSH
      uses: webfactory/ssh-agent@v0.8.0
      with:
        ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

    - name: Add server to known hosts
      run: |
        mkdir -p ~/.ssh
        ssh-keyscan -H ${{ secrets.SERVER_IP }} >> ~/.ssh/known_hosts

    - name: Deploy to server
      run: |
        ssh ${{ secrets.SSH_USERNAME }}@${{ secrets.SERVER_IP }} "
          # Создаем папку для проекта
          mkdir -p ~/apps/my-app
          
          # Копируем файлы проекта
          rsync -avz --delete ./ ${{ secrets.SSH_USERNAME }}@${{ secrets.SERVER_IP }}:~/apps/my-app/
          
          # Заходим в папку и запускаем деплой скрипт
          cd ~/apps/my-app
          chmod +x deploy.sh
          ./deploy.sh
        "
```

### **Шаг 5: Создание деплой-скрипта на сервере**

Создайте файл `deploy.sh` в корне вашего проекта:

```bash
#!/bin/bash

# deploy.sh - скрипт для деплоя на сервере

set -e  # Остановиться при любой ошибке

echo "Starting deployment..."

# Переходим в директорию проекта
cd ~/apps/my-app

# Pull последние изменения (если используем git на сервере)
# git pull origin main

# Устанавливаем зависимости
echo "Installing dependencies..."
npm install --production

# Строим приложение (если нужно)
echo "Building application..."
npm run build

# Останавливаем предыдущую версию приложения
echo "Stopping previous version..."
pm2 stop my-app || true

# Запускаем приложение с помощью PM2
echo "Starting application..."
pm2 start npm --name "my-app" -- start
pm2 save

# Настраиваем автозапуск PM2 при загрузке системы
pm2 startup | tail -1 | sh

echo "Deployment completed successfully!"
```

### **Шаг 6: Альтернативный вариант с Docker**

Если вы используете Docker, вот упрощённый workflow:

```yaml
name: Deploy with Docker

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4

    - name: Build Docker image
      run: |
        docker build -t my-app:latest .

    - name: Deploy with Docker
      uses: appleboy/ssh-action@v1.0.3
      with:
        host: ${{ secrets.SERVER_IP }}
        username: ${{ secrets.SSH_USERNAME }}
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          cd ~/apps/my-app
          docker-compose down
          docker-compose up -d
```

И соответствующий `docker-compose.yml`:
```yaml
version: '3.8'
services:
  app:
    image: my-app:latest
    ports:
      - "3000:3000"
    restart: always
```

---

## **Важные моменты для бесплатных серверов**

### **Экономия ресурсов:**
```yaml
# В workflow файле можно добавить кэширование
- name: Cache node modules
  uses: actions/cache@v3
  with:
    path: node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

### **Безопасность:**
- Никогда не коммитьте секреты в код
- Используйте разные SSH-ключи для разных проектов
- Регулярно обновляйте сервер
- Настройте firewall (ufw)

### **Мониторинг использования:**
- Следите за лимитами бесплатного тарифа
- Настройте уведомления о приближении к лимитам
- Используйте мониторинг ресурсов на сервере

---

## **Проверка работы**

1. Сделайте push в ветку `main`
2. Перейдите в репозитории на вкладку **Actions**
3. Следите за выполнением workflow
4. Если всё настроено правильно, ваше приложение будет автоматически развёрнуто на сервере

Этот подход даёт вам полный контроль над процессом деплоя и работает с любым VPS, включая бесплатные варианты от Oracle Cloud и других провайдеров.