Самый простой вариант CD сервера на той же машине - использовать **GitLab Runner с shell executor** и простые bash-скрипты для деплоя.

## 1. Настройка GitLab Runner для локального деплоя

```bash
# Если runner не установлен
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt install gitlab-runner

# Добавляем пользователя gitlab-runner в нужные группы
sudo usermod -a -G www-data gitlab-runner
sudo usermod -a -G git gitlab-runner
```

## 2. Регистрация Runner для локального деплоя

```bash
sudo gitlab-runner register
```

**Параметры регистрации:**
- GitLab instance URL: `http://localhost`
- Registration token: (получите в GitLab: Project → Settings → CI/CD → Runners)
- Description: `local-deploy-runner`
- Tags: `deploy, shell, local`
- Executor: `shell`

## 3. Создание директорий для деплоя

```bash
# Создаем директории для разных окружений
sudo mkdir -p /var/www/deploy/production
sudo mkdir -p /var/www/deploy/staging

# Даем права gitlab-runner
sudo chown -R gitlab-runner:www-data /var/www/deploy
sudo chmod -R 775 /var/www/deploy
```

## 4. Простой .gitlab-ci.yml для деплоя

Создайте в корне вашего проекта:

```yaml
stages:
  - test
  - deploy

variables:
  DEPLOY_DIR: "/var/www/deploy"

# Тестирование
test:
  stage: test
  script:
    - echo "Running tests"
    - whoami
    - pwd
    - ls -la
  only:
    - main
    - develop

# Деплой на staging
deploy_staging:
  stage: deploy
  script:
    - echo "Deploying to staging..."
    - mkdir -p $DEPLOY_DIR/staging
    - cp -r * $DEPLOY_DIR/staging/
    - echo "Staging deployment completed!"
  environment:
    name: staging
    url: http://localhost/staging
  only:
    - develop

# Деплой на production
deploy_production:
  stage: deploy
  script:
    - echo "Deploying to production..."
    - mkdir -p $DEPLOY_DIR/production
    - cp -r * $DEPLOY_DIR/production/
    - echo "Production deployment completed!"
  environment:
    name: production
    url: http://localhost/production
  only:
    - main
  when: manual
```

## 5. Настройка nginx для обслуживания деплой-директорий

Добавьте в ваш nginx конфиг (`/etc/nginx/sites-available/gitlab-proxy`):

```nginx
server {
    listen 80;
    server_name localhost;

    # Прокси для GitLab
    location / {
        proxy_pass http://localhost:8084;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Деплой-директории
    location /staging/ {
        alias /var/www/deploy/staging/;
        try_files $uri $uri/ =404;
        index index.html index.htm;
        
        # Разрешаем листинг директорий для тестирования
        autoindex on;
    }

    location /production/ {
        alias /var/www/deploy/production/;
        try_files $uri $uri/ =404;
        index index.html index.htm;
        autoindex on;
    }

    # Ваши существующие проекты
    location /test-project/ {
        alias /var/www/test-project/;
        try_files $uri $uri/ =404;
        index index.html;
    }

    location /develop-project/ {
        alias /var/www/develop-project/;
        try_files $uri $uri/ =404;
        index index.html;
    }
}
```

## 6. Упрощенная версия для быстрого старта

Если хотите совсем просто, создайте базовый `.gitlab-ci.yml`:

```yaml
stages:
  - deploy

deploy:
  stage: deploy
  script:
    - echo "🚀 Starting deployment..."
    - DEPLOY_PATH="/var/www/deploy/$(echo $CI_COMMIT_REF_NAME | tr '/' '-')"
    - mkdir -p $DEPLOY_PATH
    - cp -r . $DEPLOY_PATH/
    - echo "✅ Deployed to: $DEPLOY_PATH"
    - echo "🌐 Access via: http://localhost/deploy/$(echo $CI_COMMIT_REF_NAME | tr '/' '-')"
  only:
    - main
    - develop
```

И добавьте в nginx:

```nginx
location /deploy/ {
    alias /var/www/deploy/;
    autoindex on;
    try_files $uri $uri/ =404;
}
```

## 7. Настройка прав для беспроблемного деплоя

```bash
# Даем gitlab-runner права на запись
sudo chown -R gitlab-runner:www-data /var/www/deploy
sudo chmod -R 775 /var/www/deploy

# Разрешаем gitlab-runner перезапускать службы если нужно
sudo visudo
```

Добавьте в конец файла:
```
gitlab-runner ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
```

## 8. Тестовый проект для проверки

Создайте простой HTML файл в вашем проекте:

**index.html**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Deployment Test</title>
</head>
<body>
    <h1>🚀 Successfully Deployed!</h1>
    <p>Branch: <span id="branch"></span></p>
    <p>Time: <span id="time"></span></p>
    <script>
        document.getElementById('branch').textContent = window.location.pathname;
        document.getElementById('time').textContent = new Date().toLocaleString();
    </script>
</body>
</html>
```

## 9. Команды для применения изменений

```bash
# Применить nginx конфиг
sudo nginx -t
sudo systemctl reload nginx

# Перезапустить runner
sudo gitlab-runner restart

# Проверить статус
sudo gitlab-runner status
```

## 10. Проверка работы

1. **Запушите изменения** в GitLab
2. **Перейдите в CI/CD → Pipelines** в вашем проекте
3. **Нажмите на пайплайн** чтобы увидеть логи
4. **После успешного деплоя** откройте:
   - Staging: http://localhost/staging/
   - Production: http://localhost/production/

## 11. Дополнительные улучшения (опционально)

### Автоматический деплой с веб-хуком
```bash
# В проекте: Settings → Webhooks
# URL: http://localhost/api/v4/projects/1/ref/main
# Secret Token: (сгенерируйте в Settings → Access Tokens)
```

### Резервное копирование перед деплоем
Добавьте в `.gitlab-ci.yml`:
```yaml
before_script:
  - BACKUP_DIR="/var/www/backups/$(date +%Y%m%d_%H%M%S)"
  - mkdir -p $BACKUP_DIR
  - cp -r $DEPLOY_DIR/staging/ $BACKUP_DIR/ || echo "No previous deployment"
```

## 12. Мониторинг деплоев

Создайте простую страницу статуса:

**deploy-status.html** (положите в корень проекта)
```html
<!DOCTYPE html>
<html>
<head>
    <title>Deployment Status</title>
    <style>
        .success { color: green; }
        .failed { color: red; }
    </style>
</head>
<body>
    <h1>Deployment Status</h1>
    <div id="status">
        <p>Staging: <span class="success">✅ Live</span></p>
        <p>Production: <span class="success">✅ Live</span></p>
        <p>Last deployed: <span id="lastDeploy">Loading...</span></p>
    </div>
</body>
</html>
```

Теперь у вас есть простой, но функциональный CD сервер на той же машине! При каждом пуше в GitLab будет автоматически разворачиваться новая версия вашего приложения.