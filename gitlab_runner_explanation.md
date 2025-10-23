# GitLab Runner: подробное описание работы

## 1. Архитектура GitLab Runner

### Компоненты Runner:
- **GitLab Runner** - основное приложение
- **Executor** - среда выполнения jobs (Docker, Shell, Kubernetes)
- **Config.toml** - файл конфигурации
- **GitLab Server** - координация и управление

## 2. Установка и регистрация Runner

### Установка на Ubuntu:
```bash
# Добавление репозитория
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash

# Установка
sudo apt-get install gitlab-runner

# Запуск службы
sudo systemctl enable gitlab-runner
sudo systemctl start gitlab-runner
```

### Регистрация Runner:
```bash
sudo gitlab-runner register
```

## 3. Процесс регистрации Runner

```mermaid
sequenceDiagram
    participant A as Администратор
    participant R as GitLab Runner
    participant G as GitLab Server

    Note over A,R: 1. Получение токенов
    A->>G: Заходит в GitLab Project/Group/Admin
    G->>A: Показывает Registration Tokens
    
    Note over R,G: 2. Процесс регистрации
    A->>R: Запускает gitlab-runner register
    R->>G: Запрос: POST /api/v4/runners
    G->>R: Ответ: {runner_id, token}
    
    Note over R,R: 3. Сохранение конфигурации
    R->>R: Создает /etc/gitlab-runner/config.toml
    R->>R: Сохраняет runner_id и authentication token
    
    Note over R,G: 4. Подтверждение регистрации
    R->>G: Запрос статуса: GET /api/v4/runners/verify
    G->>R: Ответ: ✅ Runner active
    
    Note over A,G: 5. Активация в интерфейсе
    G->>A: Новый runner отображается в Settings → CI/CD
    A->>G: Настраивает tags, description
```

## 4. Детальная конфигурация config.toml

```toml
# Глобальные настройки
concurrent = 4          # Максимум одновременных jobs
check_interval = 0      # Интервал опроса сервера (секунды)

# Настройки логов
log_level = "info"
log_format = "text"

# Настройки сессий
session_timeout = 1800  # Таймаут сессии (секунды)

[[runners]]
  # Основные настройки runner
  name = "ubuntu-docker-runner"
  url = "https://gitlab.example.com"
  token = "glrt-xxxxxxxxxxxxxxxx"  # Authentication token
  executor = "docker"              # Тип исполнителя
  
  # Настройки Docker executor
  [runners.docker]
    image = "alpine:latest"        # Образ по умолчанию
    privileged = false             # Привилегированный режим
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
    shm_size = 0
    
  # Кэширование
  [runners.cache]
    Type = "s3"                    # Тип кэша
    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      AccessKey = "your-access-key"
      SecretKey = "your-secret-key"
      BucketName = "gitlab-runner-cache"
      BucketLocation = "us-east-1"
      
  # Настройки контейнера
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.gcs]
    [runners.cache.azure]
```

## 5. Полный процесс выполнения CI/CD Pipeline

```mermaid
sequenceDiagram
    participant D as Developer
    participant G as GitLab Server
    participant R as GitLab Runner
    participant C as Cache Storage
    participant S as Docker Registry
    participant E as External Services

    Note over D,G: 1. Инициализация Pipeline
    D->>G: git push origin feature-branch
    G->>G: Обнаруживает .gitlab-ci.yml
    G->>G: Создает Pipeline с jobs
    G->>G: Помещает jobs в очередь
    
    Note over G,R: 2. Распределение jobs
    loop Каждые 3 секунды
        R->>G: Запрос: GET /api/v4/jobs/request
        alt Есть доступные jobs
            G->>R: Ответ: job metadata + токен
        else Нет jobs
            G->>R: 204 No Content
        end
    end
    
    Note over R,R: 3. Подготовка окружения
    R->>R: Анализирует .gitlab-ci.yml
    R->>S: Pull docker image (если executor=docker)
    R->>G: Клонирование репозитория (с job token)
    R->>C: Загрузка cache (если существует)
    R->>R: Подготовка workspace
    
    Note over R,R: 4. Выполнение job
    R->>R: Выполняет before_script
    R->>R: Выполняет script команды
    R->>E: Взаимодействие с внешними сервисами
    R->>R: Выполняет after_script
    
    Note over R,R: 5. Сохранение результатов
    R->>R: Создает архив artifacts
    R->>G: Загрузка artifacts на GitLab
    R->>C: Сохранение обновленного cache
    R->>R: Очистка рабочего окружения
    
    Note over R,G: 6. Отчет о выполнении
    R->>G: PATCH /api/v4/jobs/{id} - обновление статуса
    alt Job успешен
        R->>G: ✅ status: success
        R->>G: Загружает логи выполнения
        R->>G: Загружает reports (junit, coverage)
    else Job провален
        R->>G: ❌ status: failed
        R->>G: Загружает логи ошибок
    end
    
    Note over G,D: 7. Завершение Pipeline
    G->>G: Обновляет статус Pipeline
    G->>D: Уведомление в Merge Request
    G->>D: Email уведомление
```

## 6. Типы Executors и их работа

### Docker Executor (наиболее популярный):
```toml
[[runners]]
  executor = "docker"
  [runners.docker]
    image = "node:16"
    privileged = false
    volumes = [
      "/cache",
      "/builds:/builds",
      "/var/run/docker.sock:/var/run/docker.sock"
    ]
    pull_policy = "if-not-present"
```

### Shell Executor:
```toml
[[runners]]
  executor = "shell"
  environment = [
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  ]
```

### Kubernetes Executor:
```toml
[[runners]]
  executor = "kubernetes"
  [runners.kubernetes]
    namespace = "gitlab-runner"
    cpu_limit = "1"
    memory_limit = "1Gi"
```

## 7. Процесс клонирования репозитория

```mermaid
sequenceDiagram
    participant R as GitLab Runner
    participant G as GitLab Server
    participant W as Workspace

    Note over R,G: 1. Аутентификация
    R->>G: Запрос клонирования с job token
    G->>R: Проверка прав доступа
    
    Note over R,W: 2. Подготовка
    R->>W: Создает директорию /builds/group/project
    R->>W: Инициализирует git репозиторий
    
    Note over R,G: 3. Клонирование
    R->>G: git fetch (только нужный коммит)
    R->>G: git checkout $CI_COMMIT_SHA
    R->>W: Сохраняет файлы в workspace
    
    Note over R,R: 4. Настройка
    R->>R: Устанавливает git config user.email
    R->>R: Устанавливает git config user.name
    R->>R: Создает .gitlab-ci.yml переменные
```

## 8. Кэширование и artifacts

### Процесс работы с кэшем:
```mermaid
flowchart TB
    A[Start Job] --> B{Check Cache Key}
    
    B --> C[Cache Found]
    B --> D[Cache Not Found]
    
    C --> E[Download Cache]
    E --> F[Extract to Paths]
    
    D --> G[Initialize Empty]
    
    F --> H[Execute Job]
    G --> H
    
    H --> I[Job Completed]
    
    I --> J{Update Cache?}
    J --> K[Yes: Create Archive]
    J --> L[No: Skip]
    
    K --> M[Upload to Cache Storage]
    M --> N[End Job]
    L --> N
```

### Конфигурация кэша в .gitlab-ci.yml:
```yaml
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/
    - .npm/
  policy: pull-push

build:
  stage: build
  script:
    - npm install
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 week
```

## 9. Мониторинг и отладка Runner

### Команды управления:
```bash
# Статус runner
sudo gitlab-runner status

# Список зарегистрированных runners
sudo gitlab-runner list

# Проверка конфигурации
sudo gitlab-runner verify

# Просмотр логов
sudo journalctl -u gitlab-runner -f

# Запуск в debug режиме
sudo gitlab-runner run --debug
```

### Метрики и мониторинг:
```toml
# В config.toml
metrics_server = ":9252"  # Prometheus metrics endpoint

# Проверка метрик
curl http://localhost:9252/metrics
```

## 10. Безопасность Runner

### Рекомендации по безопасности:
```toml
[[runners]]
  # Ограничение tags
  tag_list = ["docker", "linux"]
  
  # Запуск от непривилегированного пользователя
  [runners.docker]
    privileged = false
    userns_mode = "host"
    
  # Ограничение сетевого доступа
  [runners.docker]
    network_mode = "bridge"
    extra_hosts = ["gitlab.example.com:192.168.1.100"]
```

