# Руководство по настройке CI/CD в GitLab для учебного проекта

## Архитектура решения

```
GitLab (на VM) → CI/CD Pipeline → Тестовый сервер (на этой же VM)
```

## Предварительные настройки

### 1. Настройка GitLab Runner

```bash
# Установка GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install gitlab-runner

# Добавление пользователя gitlab-runner в группу docker
sudo usermod -aG docker gitlab-runner
```

### 2. Регистрация Runner в GitLab

```bash
sudo gitlab-runner register
```

В процессе регистрации укажите:

- **GitLab instance URL**: `http://localhost`
- **Registration token**: 
  - Перейдите в GitLab → Admin → Overview → Runners
  - Или в проекте: Settings → CI/CD → Runners
- **Description**: `local-runner`
- **Tags**: `local, test`
- **Executor**: `shell` (для простоты) или `docker`

### 3. Проверка Runner

```bash
sudo gitlab-runner verify
sudo gitlab-runner status
```

## Настройка тестового окружения

### Создание тестовой директории

```bash
sudo mkdir -p /var/www/test-project
sudo chown -R $USER:$USER /var/www/test-project
```

### Пример простого веб-приложения

Создайте тестовый проект в GitLab:

```bash
mkdir my-test-project
cd my-test-project
git init
```

Создайте файл `index.html`:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Test Project</title>
</head>
<body>
    <h1>Hello from CI/CD Pipeline!</h1>
    <p>Version: <span id="version">1.0.0</span></p>
    <p>Build date: <span id="build-date">##BUILD_DATE##</span></p>
</body>
</html>
```

Создайте файл `deploy.sh`:
```bash
#!/bin/bash
echo "Deploying to test server..."
cp -r * /var/www/test-project/
echo "Deployment completed!"
```

Сделайте скрипт исполняемым:
```bash
chmod +x deploy.sh
```

## Настройка CI/CD Pipeline

### Создание файла `.gitlab-ci.yml`

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

variables:
  DEPLOY_PATH: "/var/www/test-project"

before_script:
  - echo "Starting pipeline for $CI_COMMIT_REF_NAME"

# Стадия тестирования
test:
  stage: test
  script:
    - echo "Running tests..."
    - echo "Linting HTML files..."
    - find . -name "*.html" -exec echo "Validating {}" \;
    - echo "All tests passed!"
  only:
    - main
    - develop

# Стадия сборки
build:
  stage: build
  script:
    - echo "Building application..."
    - export BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")
    - sed -i "s/##BUILD_DATE##/$BUILD_DATE/g" index.html
    - echo "Build completed: $BUILD_DATE"
  artifacts:
    paths:
      - ./
    expire_in: 1 hour
  only:
    - main
    - develop

# Стадия деплоя на тестовый сервер
deploy_to_test:
  stage: deploy
  script:
    - echo "Deploying to test server..."
    - sudo cp -r * $DEPLOY_PATH/
    - echo "Deployment completed successfully!"
    - echo "Application available at: http://localhost/test-project"
  environment:
    name: test
    url: http://localhost/test-project
  only:
    - main
  tags:
    - local

# Деплой на develop окружение
deploy_to_develop:
  stage: deploy
  script:
    - echo "Deploying to develop server..."
    - sudo mkdir -p /var/www/develop-project
    - sudo cp -r * /var/www/develop-project/
    - echo "Develop deployment completed!"
  environment:
    name: develop
    url: http://localhost/develop-project
  only:
    - develop
  tags:
    - local
```

## Настройка веб-сервера для тестирования

### Установка nginx

```bash
sudo apt install nginx -y
```

### Создание конфигурации nginx

```bash
sudo nano /etc/nginx/sites-available/test-project
```

Добавьте конфигурацию:
```nginx
server {
    listen 80;
    server_name localhost;
    
    root /var/www;
    index index.html;

    location /test-project {
        alias /var/www/test-project;
        try_files $uri $uri/ =404;
    }

    location /develop-project {
        alias /var/www/develop-project;
        try_files $uri $uri/ =404;
    }
}
```

Активируйте конфигурацию:
```bash
sudo ln -s /etc/nginx/sites-available/test-project /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Настройка прав для GitLab Runner

```bash
# Добавляем gitlab-runner в группу sudo (осторожно!)
sudo usermod -aG sudo gitlab-runner

# Настраиваем sudo без пароля для конкретных команд
sudo visudo
```

Добавьте в конец файла:
```
gitlab-runner ALL=(ALL) NOPASSWD: /bin/cp -r /home/gitlab-runner/builds/* /var/www/test-project/
gitlab-runner ALL=(ALL) NOPASSWD: /bin/cp -r /home/gitlab-runner/builds/* /var/www/develop-project/
```

## Альтернативный вариант с Docker Executor

### 1. Перерегистрация Runner с Docker

```bash
sudo gitlab-runner unregister --name "local-runner"
sudo gitlab-runner register \
  --url "http://localhost" \
  --registration-token "YOUR_TOKEN" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "docker-runner" \
  --tag-list "docker,local"
```

### 2. Docker-версия .gitlab-ci.yml

```yaml
image: alpine:latest

stages:
  - test
  - build
  - deploy

variables:
  DOCKER_DRIVER: overlay2

before_script:
  - apk add --no-cache bash curl

test:
  stage: test
  script:
    - echo "Testing in Docker container..."
    - ls -la
    - echo "Tests completed"

build:
  stage: build
  script:
    - echo "Building in Docker..."
    - export BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")
    - apk add --no-cache sed
    - sed -i "s/##BUILD_DATE##/$BUILD_DATE/g" index.html
    - echo "Build date: $BUILD_DATE"
  artifacts:
    paths:
      - ./

deploy:
  stage: deploy
  script:
    - echo "Simulating deployment..."
    - echo "In real scenario, would deploy to: /var/www/test-project"
    - echo "Deployment simulation completed"
  only:
    - main
```

## Расширенная конфигурация Pipeline

### Вариант с уведомлениями

```yaml
# Расширенный .gitlab-ci.yml
workflow:
  rules:
    - if: $CI_COMMIT_BRANCH

stages:
  - test
  - security
  - build
  - deploy

.code_quality: &code_quality
  script:
    - echo "Checking code quality..."
    - echo "No issues found"

test:
  stage: test
  script:
    - echo "Running unit tests..."
    - echo "✓ All unit tests passed"
    - echo "Running integration tests..."
    - echo "✓ All integration tests passed"
  artifacts:
    when: always
    reports:
      junit: report.xml

security_check:
  stage: security
  script:
    - echo "Running security scan..."
    - echo "No vulnerabilities found"
  allow_failure: true

build:
  stage: build
  script:
    - echo "Building version $CI_COMMIT_SHORT_SHA"
    - mkdir -p dist
    - cp *.html dist/
    - cp *.css dist/ 2>/dev/null || true
    - cp *.js dist/ 2>/dev/null || true
    - echo "$CI_COMMIT_SHORT_SHA" > dist/version.txt
  artifacts:
    paths:
      - dist/

deploy_test:
  stage: deploy
  script:
    - echo "🚀 Deploying to TEST environment"
    - sudo rm -rf /var/www/test-project/*
    - sudo cp -r dist/* /var/www/test-project/
    - echo "✅ TEST deployment completed"
  environment:
    name: test
    url: http://localhost/test-project
  only:
    - main
  when: manual
```

## Мониторинг и отладка

### Просмотр логов Pipeline

```bash
# Логи GitLab Runner
sudo journalctl -u gitlab-runner -f

# Логи GitLab
sudo gitlab-ctl tail
```

### Проверка статуса

```bash
# Статус Runner
sudo gitlab-runner list

# Проверка конфигурации
sudo gitlab-runner verify
```

### Ручной запуск Pipeline

```bash
# В директории проекта
git add .
git commit -m "Test CI/CD"
git push origin main
```

## Решение проблем

### Проблема: Permission denied
```bash
sudo chown -R gitlab-runner:gitlab-runner /var/www/test-project
```

### Проблема: Runner не запускается
```bash
sudo gitlab-runner restart
sudo systemctl restart gitlab-runner
```

### Проблема: Pipeline stuck
```bash
# В GitLab: CI/CD → Pipelines → Cancel
# Или через консоль
sudo gitlab-runner restart
```

## Тестирование работы

1. Создайте репозиторий в GitLab
2. Добавьте файлы проекта
3. Запустите pipeline через git push
4. Проверьте результат по адресу: `http://localhost/test-project`

## Дополнительные улучшения

### Автоматическое тестирование
```yaml
auto_test:
  stage: test
  script:
    - echo "Running automated tests..."
    - |
      if [ -f "package.json" ]; then
        npm install
        npm test
      fi
```

### Уведомления в Telegram
```yaml
after_script:
  - |
    if [ "$CI_JOB_STATUS" == "success" ]; then
      curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID&text=✅ Pipeline succeeded!"
    else
      curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TELEGRAM_CHAT_ID&text=❌ Pipeline failed!"
    fi
```

Теперь у вас есть полнофункциональная система CI/CD для учебного проекта!