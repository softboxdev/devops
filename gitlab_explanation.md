# Архитектура GitLab

## 1. Архитектура GitLab

### Компоненты GitLab:
- **GitLab Rails** - основное веб-приложение (Ruby on Rails)
- **GitLab Workhorse** - Go-сервер для обработки Git-запросов
- **PostgreSQL** - основная база данных
- **Redis** - кэширование и сессии
- **NGINX** - веб-сервер и прокси
- **Sidekiq** - обработка фоновых задач
- **Gitaly** - сервис для операций с Git-репозиториями
- **GitLab Pages** - хостинг статических сайтов
- **GitLab Runner** - выполнение CI/CD задач

## 2. Установка GitLab на Ubuntu

### Требования к системе:
```bash
# Минимальные требования
CPU: 4 ядра
RAM: 4 GB
HDD: 50 GB свободного места
OS: Ubuntu 20.04/22.04 LTS
```

### Пошаговая установка:
```bash
# 1. Обновление системы
sudo apt update && sudo apt upgrade -y

# 2. Установка зависимостей
sudo apt install -y curl openssh-server ca-certificates tzdata perl

# 3. Установка Postfix для email уведомлений
sudo apt install -y postfix
# Выбираем 'Internet Site' и указываем доменное имя

# 4. Добавление репозитория GitLab
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash

# 5. Установка GitLab CE (Community Edition)
sudo EXTERNAL_URL="http://your-server-domain.com" apt install gitlab-ce

# Или установка с IP адресом
sudo EXTERNAL_URL="http://192.168.1.100" apt install gitlab-ce
```

## 3. Файловая структура GitLab

### Основные директории:
```bash
/etc/gitlab/           # Конфигурационные файлы
/opt/gitlab/           # Основные файлы приложения
/var/opt/gitlab/       # Данные приложения
/var/log/gitlab/       # Логи
```

### Детальная структура:
```
/etc/gitlab/
├── gitlab.rb          # Основной конфигурационный файл
└── gitlab-secrets.json # Файл с секретами

/opt/gitlab/
├── embedded/          # Встроенные зависимости
├── bin/               # Исполняемые файлы
└── service/           # Сервисные скрипты

/var/opt/gitlab/
├── postgresql/        # База данных PostgreSQL
├── redis/             # Данные Redis
├── gitlab-rails/      # Данные Rails приложения
├── gitlab-workhorse/  # Данные Workhorse
└── gitaly/           # Git репозитории

/var/log/gitlab/
├── nginx/             # Логи веб-сервера
├── postgresql/        # Логи БД
├── redis/             # Логи Redis
├── gitlab-rails/      # Логи основного приложения
└── sidekiq/          # Логи фоновых задач
```

## 4. Сетевые порты GitLab

### Основные порты:
```bash
# Проверка открытых портов
sudo netstat -tlnp | grep gitlab

# Или с помощью ss
sudo ss -tlnp | grep gitlab
```

| Порт | Служба | Назначение | Конфигурация |
|------|--------|------------|--------------|
| 80 | NGINX | HTTP веб-интерфейс | `external_url` |
| 443 | NGINX | HTTPS веб-интерфейс | `external_url` |
| 22 | SSH | Git-over-SSH | `gitlab_rails['gitlab_shell_ssh_port']` |
| 8080 | GitLab Workhorse | Внутренний прокси | - |
| 9090 | Prometheus | Мониторинг | - |
| 9187 | Postgres Exporter | Метрики PostgreSQL | - |
| 9236 | Redis Exporter | Метрики Redis | - |

### Настройка портов в конфигурации:
```ruby
# /etc/gitlab/gitlab.rb

# Основной URL
external_url 'http://gitlab.example.com:80'

# SSH порт для Git
gitlab_rails['gitlab_shell_ssh_port'] = 22

# Изменение HTTP порта
nginx['listen_port'] = 8080
nginx['listen_https'] = false
```

## 5. Детальная расшифровка конфигурации `/etc/gitlab/gitlab.rb`

### Базовые настройки:
```ruby
# external_url - основной URL для доступа к GitLab
external_url 'http://gitlab.example.com'

# git_data_dirs - расположение Git репозиториев
git_data_dirs({
  "default" => {
    "path" => "/var/opt/gitlab/git-data"
  }
})
```

### Настройки базы данных PostgreSQL:
```ruby
# postgresql - настройки встроенной PostgreSQL
postgresql['enable'] = true
postgresql['listen_address'] = 'localhost'
postgresql['port'] = 5432
postgresql['data_dir'] = '/var/opt/gitlab/postgresql/data'
postgresql['shared_preload_libraries'] = 'pg_stat_statements'

# Настройки производительности БД
postgresql['max_connections'] = 200
postgresql['shared_buffers'] = '256MB'
postgresql['work_mem'] = '8MB'
```

### Настройки Redis:
```ruby
# redis - настройки кэширования и сессий
redis['enable'] = true
redis['bind'] = '127.0.0.1'
redis['port'] = 6379
redis['password'] = 'your-redis-password'

# Настройки производительности Redis
redis['maxmemory'] = '512mb'
redis['maxmemory_policy'] = 'allkeys-lru'
```

### Настройки веб-сервера NGINX:
```ruby
# nginx - настройки веб-сервера
nginx['enable'] = true
nginx['listen_addresses'] = ['*']
nginx['listen_port'] = 80
nginx['listen_https'] = false

# SSL настройки (если используется HTTPS)
nginx['ssl_certificate'] = "/etc/gitlab/ssl/gitlab.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/gitlab.key"

# Производительность
nginx['worker_processes'] = 4
nginx['worker_connections'] = 10240
```

### Настройки основного приложения:
```ruby
# gitlab_rails - настройки Rails приложения
gitlab_rails['time_zone'] = 'UTC'
gitlab_rails['gitlab_email_from'] = 'gitlab@example.com'
gitlab_rails['gitlab_email_reply_to'] = 'noreply@example.com'

# Настройки базы данных
gitlab_rails['db_adapter'] = 'postgresql'
gitlab_rails['db_encoding'] = 'unicode'
gitlab_rails['db_host'] = '127.0.0.1'
gitlab_rails['db_port'] = 5432
gitlab_rails['db_username'] = 'gitlab'
gitlab_rails['db_password'] = 'your-db-password'

# Настройки Redis
gitlab_rails['redis_host'] = '127.0.0.1'
gitlab_rails['redis_port'] = 6379
gitlab_rails['redis_password'] = 'your-redis-password'

# Безопасность
gitlab_rails['initial_root_password'] = 'secure-root-password'
```

### Настройки мониторинга:
```ruby
# prometheus - система мониторинга
prometheus['enable'] = true
prometheus['listen_address'] = 'localhost:9090'

# grafana - дашборды мониторинга
grafana['enable'] = true
grafana['admin_password'] = 'grafana-password'

# node_exporter - метрики системы
node_exporter['enable'] = true
```

### Настройки резервного копирования:
```ruby
# backup - настройки бэкапов
gitlab_rails['backup_path'] = "/var/opt/gitlab/backups"
gitlab_rails['backup_archive_permissions'] = 0644
gitlab_rails['backup_keep_time'] = 604800  # 7 дней

# Email уведомления о бэкапах
gitlab_rails['backup_upload_connection'] = {
  'provider' => 'AWS',
  'region' => 'eu-west-1',
  'aws_access_key_id' => 'AKIAKIAKI',
  'aws_secret_access_key' => 'secret123'
}
```

## 6. Управление сервисами GitLab

### Команды управления:
```bash
# Применение конфигурации
sudo gitlab-ctl reconfigure

# Просмотр статуса всех сервисов
sudo gitlab-ctl status

# Запуск/остановка всех сервисов
sudo gitlab-ctl start
sudo gitlab-ctl stop
sudo gitlab-ctl restart

# Перезапуск отдельных компонентов
sudo gitlab-ctl restart nginx
sudo gitlab-ctl restart postgresql
sudo gitlab-ctl restart gitlab-rails

# Просмотр логов
sudo gitlab-ctl tail nginx
sudo gitlab-ctl tail postgresql
sudo gitlab-ctl tail gitlab-rails

# Проверка конфигурации
sudo gitlab-rake gitlab:check
```

## 7. Настройка после установки

### Первоначальная настройка через веб-интерфейс:
1. Откройте в браузере `http://your-server-ip`
2. Установите пароль для пользователя `root`
3. Войдите с логином `root` и установленным паролем
4. Настройте административные параметры

### Настройка через консоль:
```bash
# Сброс пароля root
sudo gitlab-rake "gitlab:password:reset[root]"

# Проверка целостности
sudo gitlab-rake gitlab:check SANITIZE=true

# Очистка кэша
sudo gitlab-rake cache:clear
```

## 8. Безопасность и брандмауэр

### Настройка UFW:
```bash
# Включение UFW
sudo ufw enable

# Разрешение базовых портов
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# Для Git-over-SSH
sudo ufw allow 22/tcp

# Проверка правил
sudo ufw status
```

### Рекомендации по безопасности:
```ruby
# В /etc/gitlab/gitlab.rb

# Запрет регистрации новых пользователей
gitlab_rails['gitlab_signup_enabled'] = false

# Требование подтверждения email
gitlab_rails['gitlab_email_confirmation'] = true

# Автоматическая блокировка пользователей после неудачных попыток
gitlab_rails['gitlab_unicorn_worker_timeout'] = 60
gitlab_rails['gitlab_max_requests_duration'] = 30
```

## 9. Резервное копирование и восстановление

### Создание бэкапа:
```bash
# Ручное создание бэкапа
sudo gitlab-backup create

# Автоматическое бэкапирование (cron)
# Добавить в /etc/crontab:
0 2 * * * /opt/gitlab/bin/gitlab-backup create CRON=1
```

### Восстановление из бэкапа:
```bash
# Остановка сервисов
sudo gitlab-ctl stop unicorn
sudo gitlab-ctl stop sidekiq

# Восстановление
sudo gitlab-backup restore BACKUP=timestamp_of_backup

# Перезапуск
sudo gitlab-ctl restart
sudo gitlab-rake gitlab:check SANITIZE=true
```

