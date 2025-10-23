# Подробная инструкция настройки .gitlab-ci.yml для Yandex Cloud

## 1. Предварительные требования

### Настройки на стороне Yandex Cloud:
```bash
# Создаем сервер в Yandex Cloud
# - Ubuntu 22.04 LTS
# - Минимум 2 vCPU, 4 GB RAM
# - Публичный IP адрес
# - Открытые порты: 22 (SSH), 80 (HTTP), 443 (HTTPS)
```

### Настройки на GitLab сервере:
```bash
# Убедимся что Runner установлен
sudo gitlab-runner --version

# Проверим статус
sudo systemctl status gitlab-runner
```

## 2. Подготовка SSH ключей для деплоя

```bash
# На GitLab сервере создаем SSH ключ
ssh-keygen -t ed25519 -f ~/.ssh/yandex_cloud_deploy -C "gitlab-deploy"

# Копируем публичный ключ на Yandex Cloud сервер
ssh-copy-id -i ~/.ssh/yandex_cloud_deploy.pub username@yandex-server-ip

# Добавляем приватный ключ в GitLab CI variables
cat ~/.ssh/yandex_cloud_deploy
```

## 3. Настройка переменных в GitLab

**Settings → CI/CD → Variables**
- `YC_DEPLOY_HOST` - IP адрес Yandex Cloud сервера
- `YC_DEPLOY_USER` - пользователь для подключения (например: `ubuntu`)
- `YC_SSH_PRIVATE_KEY` - содержимое приватного SSH ключа
- `YC_PROJECT_PATH` - путь к проекту на сервере (например: `/var/www/myapp`)

## 4. Детальный .gitlab-ci.yml с комментариями

```yaml
# .gitlab-ci.yml

# Определяем этапы выполнения pipeline
stages:
  - test           # Этап тестирования
  - build          # Этап сборки
  - deploy         # Этап деплоя на Yandex Cloud

# Переменные по умолчанию для всех jobs
variables:
  # Название ветки по умолчанию
  CI_APPLICATION_REPOSITORY: $CI_REGISTRY_IMAGE/$CI_COMMIT_REF_NAME
  # Указываем теги для runner (должны совпадать с тегами в config.toml)
  TAGS: "yandex-cloud,deploy"

# Кэширование для ускорения последующих запусков
cache:
  # Ключ кэша - зависит от ветки и файла зависимостей
  key: "${CI_COMMIT_REF_SLUG}"
  paths:
    - node_modules/     # Кэшируем node_modules для Node.js проектов
    - vendor/           # Кэшируем vendor для PHP проектов
    - .cache/           # Общий кэш
  # Политика кэша - вытягивать и обновлять
  policy: pull-push

# Этап тестирования
test:
  stage: test        # Принадлежит этапу test
  tags:              # Указываем теги runner
    - yandex-cloud
  image: node:18     # Используем Node.js образ
  script:            # Команды для выполнения
    # Устанавливаем зависимости
    - npm install
    # Запускаем тесты
    - npm test
    # Запускаем линтер
    - npm run lint
  only:              # Запускать только для этих веток
    - develop
    - main
  artifacts:         # Сохраняем результаты для следующих этапов
    reports:
      junit: reports/junit.xml   # Отчеты тестов
    paths:
      - coverage/                # Данные покрытия кода

# Этап сборки
build:
  stage: build       # Принадлежит этапу build
  tags:
    - yandex-cloud
  image: node:18
  dependencies:      # Зависимости от предыдущих этапов
    - test
  script:
    # Сборка проекта
    - npm run build
    # Создание архива для деплоя
    - tar -czf dist.tar.gz dist/ package.json
  artifacts:         # Сохраняем собранные файлы
    paths:
      - dist.tar.gz             # Архив для деплоя
      - dist/                   # Собранные файлы
    expire_in: 1 week          # Хранить 1 неделю
  only:
    - develop
    - main

# Деплой на staging (develop ветка)
deploy_staging:
  stage: deploy      # Этап деплоя
  tags:
    - yandex-cloud
  image: alpine:latest  # Легкий образ для деплоя
  dependencies:
    - build
  before_script:     # Команды выполняемые перед основным скриптом
    # Устанавливаем SSH и необходимые утилиты
    - apk add --no-cache openssh-client rsync tar
    # Создаем .ssh директорию
    - mkdir -p ~/.ssh
    # Записываем приватный ключ в файл
    - echo "$YC_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    # Устанавливаем правильные права на ключ
    - chmod 600 ~/.ssh/id_rsa
    # Добавляем Yandex Cloud сервер в known_hosts
    - ssh-keyscan -H $YC_DEPLOY_HOST >> ~/.ssh/known_hosts
  script:
    # Распаковываем архив
    - tar -xzf dist.tar.gz
    # Синхронизируем файлы с сервером
    - rsync -avz --delete 
      -e "ssh -o StrictHostKeyChecking=no" 
      ./dist/ 
      $YC_DEPLOY_USER@$YC_DEPLOY_HOST:$YC_PROJECT_PATH/
    # Подключаемся к серверу и выполняем команды
    - ssh -o StrictHostKeyChecking=no $YC_DEPLOY_USER@$YC_DEPLOY_HOST "
        cd $YC_PROJECT_PATH &&
        # Устанавливаем зависимости (если нужно)
        npm install --production &&
        # Перезапускаем приложение
        pm2 restart myapp || pm2 start ecosystem.config.js
      "
  environment:       # Окружение для деплоя
    name: staging
    url: http://$YC_DEPLOY_HOST  # URL окружения
  only:
    - develop       # Деплоим только из develop ветки

# Деплой на production (main ветка)
deploy_production:
  stage: deploy
  tags:
    - yandex-cloud
  image: alpine:latest
  dependencies:
    - build
  before_script:
    - apk add --no-cache openssh-client rsync tar
    - mkdir -p ~/.ssh
    - echo "$YC_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
    - ssh-keyscan -H $YC_DEPLOY_HOST >> ~/.ssh/known_hosts
  script:
    - tar -xzf dist.tar.gz
    - rsync -avz --delete 
      -e "ssh -o StrictHostKeyChecking=no" 
      ./dist/ 
      $YC_DEPLOY_USER@$YC_DEPLOY_HOST:$YC_PROJECT_PATH/
    - ssh -o StrictHostKeyChecking=no $YC_DEPLOY_USER@$YC_DEPLOY_HOST "
        cd $YC_PROJECT_PATH &&
        npm install --production &&
        # Для production используем другую команду
        sudo systemctl restart myapp &&
        # Проверяем что приложение запустилось
        sleep 10 &&
        curl -f http://localhost:3000/health || exit 1
      "
  environment:
    name: production
    url: https://your-domain.com  # Ваш production домен
  only:
    - main          # Деплоим только из main ветки
  when: manual      # Требует ручного подтверждения

# Откат деплоя (опционально)
rollback_production:
  stage: deploy
  tags:
    - yandex-cloud
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client
    - mkdir -p ~/.ssh
    - echo "$YC_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
    - ssh-keyscan -H $YC_DEPLOY_HOST >> ~/.ssh/known_hosts
  script:
    # Откатываем на предыдущую версию (пример для git)
    - ssh -o StrictHostKeyChecking=no $YC_DEPLOY_USER@$YC_DEPLOY_HOST "
        cd $YC_PROJECT_PATH &&
        git reset --hard HEAD~1 &&
        sudo systemctl restart myapp
      "
  environment:
    name: production
    url: https://your-domain.com
  when: manual      # Всегда ручной запуск
  only:
    - main
```

## 5. Настройка GitLab Runner для Yandex Cloud

### Регистрируем Runner:
```bash
sudo gitlab-runner register
```

### Конфигурация (/etc/gitlab-runner/config.toml):
```toml
concurrent = 4
check_interval = 0

[session_server]
  listen_address = ":8093"
  advertise_address = "runner-host-ip:8093"

[[runners]]
  name = "yandex-cloud-runner"
  url = "http://your-gitlab-domain.com"  # URL вашего GitLab
  token = "your-runner-token"           # Token из GitLab Settings → CI/CD → Runners
  executor = "shell"                    # Самый простой вариант
  shell = "bash"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.custom]
    build_dir = "/builds"
  tags = "yandex-cloud,deploy"         # Теги для выбора этого runner
```

## 6. Подготовка сервера на Yandex Cloud

### Настройка сервера:
```bash
# Подключаемся к Yandex Cloud серверу
ssh ubuntu@yandex-server-ip

# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем Node.js (для примера)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Устанавливаем PM2 для управления процессами
sudo npm install -g pm2

# Создаем директорию для проекта
sudo mkdir -p /var/www/myapp
sudo chown ubuntu:ubuntu /var/www/myapp

# Создаем systemd сервис (опционально)
sudo nano /etc/systemd/system/myapp.service
```

### Пример systemd сервиса:
```ini
[Unit]
Description=My Node.js Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/myapp
ExecStart=/usr/bin/npm start
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## 7. Дополнительные скрипты для специфичных случаев

### Для PHP приложений:
```yaml
deploy_php:
  stage: deploy
  tags:
    - yandex-cloud
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client rsync
    - mkdir -p ~/.ssh
    - echo "$YC_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
  script:
    - rsync -avz --delete 
      -e "ssh -o StrictHostKeyChecking=no" 
      ./ 
      $YC_DEPLOY_USER@$YC_DEPLOY_HOST:$YC_PROJECT_PATH/ 
      --exclude='.git' 
      --exclude='.gitlab-ci.yml'
    - ssh -o StrictHostKeyChecking=no $YC_DEPLOY_USER@$YC_DEPLOY_HOST "
        cd $YC_PROJECT_PATH &&
        composer install --no-dev --optimize-autoloader &&
        php artisan migrate --force &&
        sudo systemctl reload apache2
      "
```

### Для Python приложений:
```yaml
deploy_python:
  stage: deploy
  tags:
    - yandex-cloud
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client rsync
    - mkdir -p ~/.ssh
    - echo "$YC_SSH_PRIVATE_KEY" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
  script:
    - rsync -avz --delete 
      -e "ssh -o StrictHostKeyChecking=no" 
      ./ 
      $YC_DEPLOY_USER@$YC_DEPLOY_HOST:$YC_PROJECT_PATH/ 
      --exclude='venv' 
      --exclude='.git'
    - ssh -o StrictHostKeyChecking=no $YC_DEPLOY_USER@$YC_DEPLOY_HOST "
        cd $YC_PROJECT_PATH &&
        python3 -m venv venv &&
        source venv/bin/activate &&
        pip install -r requirements.txt &&
        sudo systemctl restart my-python-app
      "
```

## 8. Проверка работоспособности

### Тестовый коммит:
```bash
# Создаем тестовый файл
echo "Test commit for CI/CD" > test.txt
git add .
git commit -m "test: testing CI/CD pipeline"
git push origin develop
```

### Мониторинг pipeline:
1. Зайдите в GitLab → ваш проект → CI/CD → Pipelines
2. Следите за выполнением каждого этапа
3. Проверьте логи в случае ошибок

## 9. Устранение частых проблем

### Проблемы с SSH:
```bash
# Проверка подключения
ssh -i ~/.ssh/yandex_cloud_deploy ubuntu@yandex-server-ip

# Проверка прав на ключ
chmod 600 ~/.ssh/yandex_cloud_deploy
```

### Проблемы с правами на сервере:
```bash
# На Yandex Cloud сервере
sudo chown -R ubuntu:ubuntu /var/www/myapp
sudo chmod -R 755 /var/www/myapp
```

