

---

## **🚀 ПОЛНАЯ ИНСТРУКЦИЯ: GITHUB ACTIONS + YANDEX CLOUD VPS**

### **📋 ПРЕДВАРИТЕЛЬНЫЕ ТРЕБОВАНИЯ**
- Аккаунт на GitHub
- VPS в Яндекс Облаке
- Базовые знания Git
- Тестовый проект (например, Node.js/Python приложение)

---

## **🛠️ ЧАСТЬ 1: ПОДГОТОВКА ПРОЕКТА**

### **Создаем тестовый проект (если нет):**

```bash
# Создаем директорию проекта
mkdir my-test-app
cd my-test-app

# Инициализируем Git репозиторий
git init

# Создаем простой Node.js проект
echo '{
  "name": "my-test-app",
  "version": "1.0.0",
  "description": "Test app for GitHub Actions",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "jest": "^29.0.0"
  }
}' > package.json

# Создаем основное приложение
echo 'const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.json({
    message: "Hello from GitHub Actions!",
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || "development"
  });
});

app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app;' > app.js

# Создаем простой тест
echo 'const app = require("./app");
const request = require("supertest");

describe("GET /", () => {
  it("should return welcome message", async () => {
    const res = await request(app).get("/");
    expect(res.statusCode).toEqual(200);
    expect(res.body.message).toContain("Hello from GitHub Actions");
  });
});' > app.test.js

# Создаем .gitignore
echo 'node_modules/
.env
*.log
.DS_Store' > .gitignore
```

---

## **🔐 ЧАСТЬ 2: НАСТРОЙКА YANDEX CLOUD VPS**

### **Шаг 2.1: Создание VPS в Яндекс Облаке**

1. **Зайдите в Яндекс Облако Console**
2. **Создайте виртуальную машину:**
   - **Образ:** Ubuntu 20.04 LTS
   - **Платформа:** Intel Cascade Lake
   - **Память:** 2 ГБ RAM
   - **Диск:** 20 ГБ SSD
   - **Публичный IP:** Включить

3. **Настройка безопасности:**
   - Откройте порты: 22 (SSH), 80 (HTTP), 443 (HTTPS)
   - Создайте/используйте существующий SSH ключ

### **Шаг 2.2: Настройка сервера**

```bash
# Подключение к серверу
ssh yc-user@your-server-ip

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Node.js (для нашего примера)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Установка PM2 для управления процессами
sudo npm install -g pm2

# Установка Nginx
sudo apt install -y nginx

# Создание директории для приложения
sudo mkdir -p /var/www/my-app
sudo chown $USER:$USER /var/www/my-app
```

### **Шаг 2.3: Настройка Nginx**

```bash
# Создаем конфиг Nginx
sudo nano /etc/nginx/sites-available/my-app
```

```nginx
server {
    listen 80;
    server_name your-server-ip;  # или ваше доменное имя

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
# Активируем сайт
sudo ln -s /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## **🔑 ЧАСТЬ 3: НАСТРОЙКА SSH ДОСТУПА ДЛЯ GITHUB ACTIONS**

### **Шаг 3.1: Создание SSH ключа для GitHub Actions**

```bash
# На локальной машине генерируем SSH ключ
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github-actions-deploy

# Копируем публичный ключ на сервер
ssh-copy-id -i ~/.ssh/github-actions-deploy.pub yc-user@your-server-ip
```

### **Шаг 3.2: Добавление секретов в GitHub**

1. **В репозитории GitHub:**
   - Settings → Secrets and variables → Actions
   - New repository secret

2. **Добавляем секреты:**
   - **SERVER_IP**: IP адрес вашего VPS
   - **SSH_PRIVATE_KEY**: Содержимое `~/.ssh/github-actions-deploy`
   - **SSH_USERNAME**: yc-user (или ваш пользователь)
   - **DEPLOY_PATH**: /var/www/my-app

```bash
# Просмотр приватного ключа для копирования
cat ~/.ssh/github-actions-deploy
```

---

## **⚙️ ЧАСТЬ 4: СОЗДАНИЕ GITHUB ACTIONS WORKFLOW**

### **Шаг 4.1: Создание workflow файла**

```bash
# В корне проекта создаем директорию
mkdir -p .github/workflows

# Создаем файл workflow
nano .github/workflows/deploy.yml
```

### **Шаг 4.2: Полный workflow файл**

```yaml
name: Deploy to Yandex Cloud VPS

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

env:
  NODE_VERSION: '18'
  SERVER_IP: ${{ secrets.SERVER_IP }}
  SSH_USER: ${{ secrets.SSH_USERNAME }}
  DEPLOY_PATH: ${{ secrets.DEPLOY_PATH }}

jobs:
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'
        
    - name: Install dependencies
      run: npm ci
      
    - name: Run tests
      run: npm test
      
    - name: Build verification
      run: npm run build --if-present

  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master'
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ env.NODE_VERSION }}
        
    - name: Install dependencies
      run: npm ci
      
    - name: Run tests
      run: npm test
      
    - name: Create deployment package
      run: |
        mkdir -p deployment
        cp -r *.js *.json *.md deployment/
        tar -czf deployment.tar.gz deployment/
        
    - name: Setup SSH
      uses: webfactory/ssh-agent@v0.8.0
      with:
        ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
        
    - name: Deploy to server
      run: |
        # Создаем директорию на сервере
        ssh -o StrictHostKeyChecking=no ${{ env.SSH_USER }}@${{ env.SERVER_IP }} "
          mkdir -p ${{ env.DEPLOY_PATH }}/releases &&
          mkdir -p ${{ env.DEPLOY_PATH }}/shared
        "
        
        # Копируем архив на сервер
        scp -o StrictHostKeyChecking=no deployment.tar.gz ${{ env.SSH_USER }}@${{ env.SERVER_IP }}:${{ env.DEPLOY_PATH }}/releases/
        
        # Разворачиваем на сервере
        ssh -o StrictHostKeyChecking=no ${{ env.SSH_USER }}@${{ env.SERVER_IP }} "
          cd ${{ env.DEPLOY_PATH }}/releases &&
          
          # Создаем уникальную директорию для релиза
          RELEASE_DIR=\"release_$(date +%Y%m%d_%H%M%S)\"
          mkdir \$RELEASE_DIR &&
          tar -xzf deployment.tar.gz -C \$RELEASE_DIR --strip-components=1 &&
          rm deployment.tar.gz &&
          
          # Устанавливаем зависимости
          cd \$RELEASE_DIR &&
          npm install --production &&
          
          # Создаем симлинк на текущий релиз
          cd ${{ env.DEPLOY_PATH }} &&
          ln -sfn releases/\$RELEASE_DIR current &&
          
          # Перезапускаем приложение через PM2
          cd current &&
          pm2 delete my-app 2>/dev/null || true &&
          pm2 start app.js --name my-app --update-env &&
          pm2 save &&
          pm2 startup 2>/dev/null
        "
        
    - name: Verify deployment
      run: |
        sleep 10  # Даем время приложению запуститься
        curl -f http://${{ env.SERVER_IP }} || exit 1
        
    - name: Notify success
      if: success()
      run: |
        echo "🚀 Deployment completed successfully!"
        echo "Application is running on: http://${{ env.SERVER_IP }}"
        
  rollback:
    name: Rollback Deployment
    runs-on: ubuntu-latest
    needs: deploy
    if: failure()
    
    steps:
    - name: Setup SSH
      uses: webfactory/ssh-agent@v0.8.0
      with:
        ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}
        
    - name: Rollback to previous version
      run: |
        ssh -o StrictHostKeyChecking=no ${{ env.SSH_USER }}@${{ env.SERVER_IP }} "
          cd ${{ env.DEPLOY_PATH }} &&
          
          # Находим предыдущий релиз
          PREVIOUS_RELEASE=\$(ls -1t releases/ | head -2 | tail -1)
          
          if [ -n \"\$PREVIOUS_RELEASE\" ]; then
            echo \"Rolling back to: \$PREVIOUS_RELEASE\"
            ln -sfn releases/\$PREVIOUS_RELEASE current &&
            
            cd current &&
            pm2 delete my-app 2>/dev/null || true &&
            pm2 start app.js --name my-app --update-env &&
            pm2 save
          else
            echo \"No previous release found for rollback\"
            exit 1
          fi
        "
```

---

## **🔧 ЧАСТЬ 5: ДОПОЛНИТЕЛЬНЫЕ КОНФИГУРАЦИИ**

### **Расширенный workflow с мониторингом:**

```yaml
name: Advanced Deploy to Yandex Cloud

on:
  push:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * *'  # Ежедневно в 2:00

env:
  NODE_ENV: production

jobs:
  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      
    - name: Run Snyk security scan
      uses: snyk/actions/node@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      with:
        args: --severity-threshold=high

  quality-check:
    name: Code Quality
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      
    - name: Super-linter
      uses: github/super-linter@v4
      env:
        DEFAULT_BRANCH: main
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
    - name: Deploy to staging
      run: echo "Deploying to staging..."
      # Добавьте вашу логику деплоя на staging

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: [security-scan, quality-check, deploy-staging]
    environment: production
    
    steps:
    - uses: actions/checkout@v4
      
    - name: Deploy to Yandex Cloud
      uses: appleboy/ssh-action@master
      with:
        host: ${{ secrets.SERVER_IP }}
        username: ${{ secrets.SSH_USERNAME }}
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          cd /var/www/my-app/current
          git pull origin main
          npm install --production
          pm2 reload my-app
```

---

## **📝 ЧАСТЬ 6: ЗАВЕРШЕНИЕ НАСТРОЙКИ**

### **Шаг 6.1: Коммит и пуш в GitHub**

```bash
# Добавляем файлы в Git
git add .
git commit -m "Add GitHub Actions deployment workflow"
git branch -M main

# Создаем репозиторий на GitHub и пушим
git remote add origin https://github.com/your-username/your-repo.git
git push -u origin main
```

### **Шаг 6.2: Проверка работы workflow**

1. **Перейдите в репозиторий на GitHub**
2. **Откройте вкладку "Actions"**
3. **Должны увидеть запущенный workflow**
4. **Проверьте логи выполнения**

### **Шаг 6.3: Тестирование деплоя**

```bash
# Проверяем приложение
curl http://your-server-ip

# Должны получить ответ:
# {"message":"Hello from GitHub Actions!","timestamp":"2024-01-01T12:00:00.000Z","environment":"production"}
```

---

## **🔍 ЧАСТЬ 7: МОНИТОРИНГ И ЛОГИРОВАНИЕ**

### **Добавляем мониторинг в workflow:**

```yaml
# Добавляем в workflow после деплоя
- name: Health check and monitoring
  run: |
    # Проверяем здоровье приложения
    response=$(curl -s -o /dev/null -w "%{http_code}" http://${{ env.SERVER_IP }}/health)
    
    if [ "$response" -eq 200 ]; then
      echo "✅ Application health check passed"
    else
      echo "❌ Application health check failed"
      exit 1
    fi
    
    # Отправляем метрики (пример с DataDog)
    curl -X POST "https://api.datadoghq.com/api/v1/series" \
      -H "Content-Type: application/json" \
      -H "DD-API-KEY: ${{ secrets.DATADOG_API_KEY }}" \
      -d '{
        "series": [{
          "metric": "deployment.success",
          "points": [[$(date +%s), 1]],
          "tags": ["environment:production", "app:my-test-app"]
        }]
      }'
```

---

## **⚠️ РЕШЕНИЕ ЧАСТЫХ ПРОБЛЕМ**

### **Проблема 1: SSH подключение не работает**
```bash
# Проверка SSH ключей
ssh -i ~/.ssh/github-actions-deploy -v yc-user@your-server-ip

# Решение: пересоздать ключи и обновить секреты
```

### **Проблема 2: Приложение не запускается**
```bash
# Проверка на сервере
pm2 list
pm2 logs my-app

# Проверка портов
netstat -tulpn | grep :3000
```

### **Проблема 3: Nginx не проксирует запросы**
```bash
# Проверка конфигурации Nginx
sudo nginx -t
sudo systemctl status nginx

# Просмотр логов Nginx
sudo tail -f /var/log/nginx/error.log
```

---

## **🎯 ФИНАЛЬНАЯ ПРОВЕРКА**

1. **✅ Код залит в GitHub**
2. **✅ Secrets настроены в репозитории**
3. **✅ VPS настроен и доступен**
4. **✅ GitHub Actions workflow выполняется**
5. **✅ Приложение доступно по IP**
6. **✅ Деплой работает автоматически**

**Теперь при каждом пуше в main ветку ваш код будет автоматически тестироваться и деплоиться на VPS Яндекс Облака! 🚀**

Дополнительные материалы:
https://dzen.ru/a/aM31ZpPy53fLYTBb