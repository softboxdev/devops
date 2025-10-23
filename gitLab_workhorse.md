# GitLab Workhorse: подробное описание работы

## 1. Что такое GitLab Workhorse

**GitLab Workhorse** - это умный обратный прокси-сервер, написанный на Go, который обрабатывает "тяжелые" HTTP-запросы, разгружая основное Rails-приложение.

### Основные функции:
- **Обработка больших файлов** - загрузка/скачивание
- **Git-операции** - clone, push, pull
- **Статические файлы** - отдача assets
- **WebSocket** - обработка Live Features
- **API-рутинг** - интеллектуальная маршрутизация запросов

## 2. Архитектура Workhorse

```mermaid
graph TB
    A[Клиент] --> B[NGINX]
    B --> C[GitLab Workhorse]
    C --> D[GitLab Rails]
    C --> E[GitLab API]
    C --> F[Gitaly]
    C --> G[Файловая система]
    
    subgraph "Workhorse Components"
        H[HTTP Server]
        I[Git HTTP Handler]
        J[File Upload Handler]
        K[Static File Handler]
        L[API Router]
    end
    
    C --> H
    H --> I
    H --> J
    H --> K
    H --> L
```

## 3. Установка и конфигурация

### Workhorse поставляется с GitLab:
```bash
# Расположение Workhorse
/opt/gitlab/embedded/bin/gitlab-workhorse
/var/opt/gitlab/gitlab-workhorse/

# Конфигурационные файлы
/var/opt/gitlab/gitlab-workhorse/config.toml
```

### Конфигурация в gitlab.rb:
```ruby
# Настройки Workhorse
gitlab_workhorse['enable'] = true
gitlab_workhorse['listen_network'] = "tcp"
gitlab_workhorse['listen_addr'] = "127.0.0.1:8181"
gitlab_workhorse['auth_backend'] = "http://127.0.0.1:8080" # GitLab Rails
gitlab_workhorse['auth_socket'] = "/var/opt/gitlab/gitlab-rails/sockets/gitlab.socket"

# Настройки производительности
gitlab_workhorse['proxy_headers_timeout'] = "1m"
gitlab_workhorse['api_limit'] = 0
gitlab_workhorse['api_queue_limit'] = 0
gitlab_workhorse['api_queue_duration'] = "30s"
```

## 4. Полный процесс обработки запроса при коммите

```mermaid
sequenceDiagram
    participant D as Developer Git Client
    participant N as NGINX
    participant W as GitLab Workhorse
    participant R as GitLab Rails
    participant G as Gitaly
    participant A as GitLab API

    Note over D,A: 1. Инициализация Git Push
    D->>N: git push origin main
    N->>W: POST /namespace/project.git/git-receive-pack
    
    Note over W,R: 2. Аутентификация запроса
    W->>R: Запрос аутентификации: GET /api/v4/internal/allowed
    R->>W: Ответ: {user_id, project, permissions, gitaly_info}
    
    alt Аутентификация успешна
        Note over W,G: 3. Подготовка Git-операции
        W->>G: Подключение к Gitaly по gRPC
        G->>W: Подтверждение готовности
        
        Note over W,D: 4. Прием данных от клиента
        W->>D: HTTP 200 Continue
        D->>W: Отправка packfile данных
        
        Note over W,G: 5. Передача данных в Gitaly
        W->>G: Передача packfile через gRPC stream
        G->>G: Обработка Git-объектов
        G->>G: Обновление references
        
        Note over G,W: 6. Подтверждение операции
        G->>W: Результат операции: success/failure
        W->>D: Git response: OK/Error
        
        Note over R,A: 7. Триггеры после коммита
        W->>R: Уведомление о успешном push
        R->>A: Создание Pipeline через API
        A->>R: Подтверждение создания Pipeline
        
        Note over R,W: 8. WebSocket уведомления
        R->>W: WebSocket: обновление интерфейса
        W->>D: Live update в GitLab UI (если открыт)
        
    else Аутентификация провалена
        R->>W: HTTP 401 Unauthorized
        W->>N: Передача ошибки
        N->>D: Git error: authentication failed
    end
```

## 5. Детальный процесс обработки Git HTTP запросов

```mermaid
sequenceDiagram
    participant C as Git Client
    participant W as Workhorse
    participant R as Rails
    participant G as Gitaly
    participant S as Sidekiq

    Note over C,S: Git Clone Operation
    C->>W: GET /project.git/info/refs?service=git-upload-pack
    W->>R: Проверка прав: GET /internal/allowed
    R->>W: {allowed: true, gitaly: {address: ...}}
    W->>G: gRPC: InfoRefsRequest
    G->>W: Git refs advertisement
    W->>C: HTTP 200 + refs data
    
    C->>W: POST /project.git/git-upload-pack
    W->>G: gRPC stream: UploadPackRequest
    G->>W: Git pack data
    W->>C: Передача packfile
    
    Note over W,S: Post-Receive Hooks
    G->>R: PostReceive hook call
    R->>S: Создание задач: UpdateMergeRequests, CreatePipeline
    S->>S: Обработка фоновых задач
```

## 6. Обработка больших файлов

```mermaid
sequenceDiagram
    participant U as User Browser
    participant W as Workhorse
    participant R as Rails
    participant S as Object Storage

    Note over U,S: 1. Загрузка большого файла
    U->>W: POST /project/uploads (multipart/form-data)
    W->>R: Запрос авторизации
    R->>W: {allowed: true, temp_path: "/path/temp"}
    
    Note over W,W: 2. Прямая обработка файла
    W->>W: Прием файла во временную директорию
    W->>W: Валидация размера и типа
    
    alt Файл валиден
        Note over W,S: 3. Сохранение в Object Storage
        W->>S: Прямая загрузка в S3/MinIO
        S->>W: URL сохраненного файла
        
        Note over W,R: 4. Уведомление Rails
        W->>R: POST с metadata {url, size, name}
        R->>W: Подтверждение сохранения
        W->>U: HTTP 200 + file info
        
    else Файл невалиден
        W->>W: Удаление временного файла
        W->>U: HTTP 413/415 Error
    end
```

## 7. Конфигурация Workhorse

### Файл config.toml:
```toml
[redis]
    Password = "redis-password"
    URL = "tcp://localhost:6379"

[auth]
    Socket = "/var/opt/gitlab/gitlab-rails/sockets/gitlab.socket"
    Backend = "http://localhost:8080"

[object_storage]
    Provider = "AWS"

[object_storage.s3]
    AWSAccessKeyID = "access-key"
    AWSSecretAccessKey = "secret-key"

[listener]
    Network = "tcp"
    Addr = ":8181"
```

## 8. Мониторинг и логи

### Метрики Workhorse:
```bash
# Статус Workhorse
sudo gitlab-ctl status gitlab-workhorse

# Логи в реальном времени
sudo gitlab-ctl tail gitlab-workhorse

# Метрики Prometheus
curl http://localhost:9229/metrics
```

### Ключевые метрики:
```prometheus
# HTTP запросы
gitlab_workhorse_http_requests_total{method="POST",code="200"}
gitlab_workhorse_http_request_duration_seconds

# Git операции
gitlab_workhorse_git_http_requests_total{type="git-receive-pack"}
gitlab_workhorse_git_http_requests_total{type="git-upload-pack"}

# Загрузка файлов
gitlab_workhorse_uploads_total
gitlab_workhorse_upload_errors_total
```

## 9. Процесс обработки WebSocket

```mermaid
sequenceDiagram
    participant U as User Browser
    participant W as Workhorse
    participant R as Rails
    participant A as Action Cable

    Note over U,A: 1. Установка WebSocket соединения
    U->>W: WebSocket Upgrade request
    W->>R: Проверка аутентификации
    R->>W: {user_id, channels}
    
    alt Аутентификация успешна
        W->>A: Proxy WebSocket to Action Cable
        A->>W: WebSocket accepted
        W->>U: HTTP 101 Switching Protocols
        
        Note over A,U: 2. Обмен сообщениями
        A->>W: Live update: new commit
        W->>U: WebSocket message
        
        U->>W: User interaction
        W->>A: Forward to Action Cable
        
    else Аутентификация провалена
        R->>W: HTTP 401
        W->>U: WebSocket connection refused
    end
```

## 10. Обработка статических файлов

```mermaid
sequenceDiagram
    participant B as Browser
    participant W as Workhorse
    participant R as Rails
    participant F as Filesystem/CDN

    B->>W: GET /assets/application-abc123.js
    W->>W: Проверка кэша ETag/Last-Modified
    
    alt В кэше
        W->>B: HTTP 304 Not Modified
    else Не в кэше
        W->>F: Проверка существования файла
        F->>W: File exists + metadata
        
        alt Файл существует
            W->>F: Чтение файла
            F->>W: File content
            W->>W: Set cache headers
            W->>B: HTTP 200 + content
        else Файл не существует
            W->>R: Проксирование в Rails
            R->>W: Динамический ответ
            W->>B: Передача ответа
        end
    end
```

## 11. Безопасность Workhorse

### Механизмы безопасности:
- **JWT токены** для внутренней аутентификации
- **Проверка прав доступа** для каждого запроса
- **Лимиты размеров** файлов
- **Валидация MIME-типов**
- **Изоляция исполнения** от основного приложения

### Конфигурация безопасности:
```ruby
# В gitlab.rb
gitlab_workhorse['trusted_cidr_for_x_forwarded_for'] = ['127.0.0.1/32']
gitlab_workhorse['trusted_cidr_for_propagation'] = ['127.0.0.1/32']
```

Эта архитектура позволяет GitLab эффективно обрабатывать тяжелые операции, разгружая Rails-приложение и обеспечивая высокую производительность даже при большой нагрузке.