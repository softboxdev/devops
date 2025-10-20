# Инструкция по установке GitLab на localhost Ubuntu 22.04

## Предварительные требования

- Ubuntu 22.04
- Минимум 4 ГБ оперативной памяти (рекомендуется 8 ГБ)
- Минимум 4 ядра CPU
- Не менее 10 ГБ свободного места на диске
- Права суперпользователя (sudo)

## 1. Обновление системы и установка зависимостей

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl openssh-server ca-certificates tzdata perl
```

## 2. Установка почтового сервера (для уведомлений)

```bash
sudo apt install -y postfix
```

При настройке Postfix выберите:
- **Local only**
- Имя почтовой системы: `localhost`

## 3. Добавление репозитория GitLab

```bash
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
```

## 4. Установка GitLab для localhost

```bash
sudo EXTERNAL_URL="http://localhost" apt install gitlab-ce
```

Или альтернативный способ:

```bash
sudo apt install gitlab-ce
```

После установки настройте external_url:
```bash
sudo nano /etc/gitlab/gitlab.rb
```

Измените строку:
```ruby
external_url 'http://localhost'
```

## 5. Настройка для работы на localhost

Отредактируйте конфигурационный файл для оптимизации под localhost:

```bash
sudo nano /etc/gitlab/gitlab.rb
```

Добавьте или измените следующие настройки:

```ruby
# Основной URL
external_url 'http://localhost'

# Отключение SSL для localhost
nginx['redirect_http_to_https'] = false
nginx['ssl_certificate'] = nil
nginx['ssl_certificate_key'] = nil

# Разрешить локальный доступ
nginx['listen_addresses'] = ['0.0.0.0']

# Уменьшение требований к памяти (для локальной разработки)
unicorn['worker_processes'] = 2
postgresql['shared_buffers'] = "256MB"
postgresql['max_worker_processes'] = 4
sidekiq['max_concurrency'] = 10

# Отключение Let's Encrypt для localhost
letsencrypt['enable'] = false
```

## 6. Применение конфигурации

```bash
sudo gitlab-ctl reconfigure
```

Этот процесс займет 5-10 минут.

## 7. Получение пароля root

```bash
sudo cat /etc/gitlab/initial_root_password
```

Сохраните пароль из вывода команды.

## 8. Проверка статуса служб

```bash
sudo gitlab-ctl status
```

Все службы должны быть в состоянии "run".

## 9. Настройка firewall (если включен)

```bash
sudo ufw allow http
sudo ufw allow ssh
sudo ufw enable
```

## 10. Доступ к GitLab

Откройте браузер и перейдите по адресу:
```
http://localhost
```

- **Логин**: `root`
- **Пароль**: из файла `/etc/gitlab/initial_root_password`

## 11. Основные команды управления

```bash
# Запуск GitLab
sudo gitlab-ctl start

# Остановка GitLab
sudo gitlab-ctl stop

# Перезапуск GitLab
sudo gitlab-ctl restart

# Проверка статуса
sudo gitlab-ctl status

# Просмотр логов
sudo gitlab-ctl tail
```

## 12. Настройка для экономии ресурсов (опционально)

Если нужно уменьшить потребление ресурсов, создайте файл подкачки:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

Добавьте в `/etc/fstab` для автоматического подключения:
```bash
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## 13. Настройка почты для локальных уведомлений

В файле `/etc/gitlab/gitlab.rb`:

```ruby
# Включение почтовых уведомлений
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "localhost"
gitlab_rails['smtp_port'] = 25
gitlab_rails['smtp_domain'] = "localhost"
gitlab_rails['smtp_authentication'] = "plain"
gitlab_rails['smtp_enable_starttls_auto'] = false
gitlab_rails['gitlab_email_from'] = "gitlab@localhost"
```

После изменений выполните:
```bash
sudo gitlab-ctl reconfigure
```

## 14. Резервное копирование

```bash
# Создание резервной копии
sudo gitlab-backup create

# Резервные копии сохраняются в /var/opt/gitlab/backups/

# Восстановление из резервной копии
sudo gitlab-backup restore BACKUP=timestamp_backup_name
```

## Решение распространенных проблем

### Порт 80 занят
```bash
# Проверить какие процессы используют порт 80
sudo lsof -i :80

# Если нужно остановить другие службы (например, nginx/apache)
sudo systemctl stop nginx
sudo systemctl disable nginx
```

### Недостаточно памяти
```bash
# Проверить использование памяти
free -h

# Создать файл подкачки (как в п.12)
```

### GitLab не запускается
```bash
# Проверить логи
sudo gitlab-ctl tail

# Перезапустить службы
sudo gitlab-ctl restart
```

### Забыт пароль root
```bash
# Сброс пароля root
sudo gitlab-rake "gitlab:password:reset[root]"
```

### Проверка работоспособности
```bash
# Проверить статус всех компонентов
sudo gitlab-rake gitlab:check SANITIZE=true
```

## Дополнительные настройки для разработки

### Отключение некоторых служб (для экономии ресурсов)
В `/etc/gitlab/gitlab.rb`:
```ruby
# Отключение мониторинга
prometheus_monitoring['enable'] = false

# Отключение Grafana
grafana['enable'] = false

# Уменьшение количества worker'ов
unicorn['worker_processes'] = 1
sidekiq['max_concurrency'] = 5
```

### Настройка для тестирования
```ruby
# Уменьшение времени ожидания
gitlab_rails['git_timeout'] = 300

# Отключение сложных проверок
gitlab_rails['gitlab_max_import_size'] = 50
```

## Автозапуск GitLab при загрузке

GitLab автоматически добавляется в автозагрузку. Для проверки:

```bash
sudo systemctl is-enabled gitlab-runsvdir
```

Если отключен, включите:
```bash
sudo systemctl enable gitlab-runsvdir
```

Теперь у вас есть полностью функционирующий GitLab на localhost! Вы можете создавать проекты, пользователей и работать с GitLab как с облачной версией.