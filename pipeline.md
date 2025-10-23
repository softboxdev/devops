
## Детальное описание процесса:

### 1. **Инициализация Pipeline**
- **Developer** делает `git push` в репозиторий
- **GitLab** обнаруживает файл `.gitlab-ci.yml`
- Создается новый **Pipeline** с уникальным ID
- Анализируются **stages** и создаются **jobs**

### 2. **Подготовка выполнения**
- Для каждого **job** находится подходящий **Runner**
- **Runner** подготавливает окружение:
  - Скачивает указанный **Docker image**
  - Клонирует код репозитория
  - Восстанавливает **cache** (если доступен)

### 3. **Выполнение этапов**
#### Stage 1: Build
- Выполняется **before_script**
- Запускаются команды **script**
- Сохраняются **artifacts** (результаты сборки)
- Обновляется **cache**

#### Stage 2: Test 
- Запускаются **services** (базы данных, Redis)
- Восстанавливаются **artifacts** из предыдущего stage
- Выполняются тесты
- Загружаются отчеты в GitLab

#### Stage 3: Deploy
- Выполняется деплой на целевое окружение
- Обновляется статус **environment** в GitLab

### 4. **Завершение Pipeline**
- **Runner** отправляет результаты в **GitLab**
- Обновляется статус **Pipeline**
- Отправляются уведомления **Developer**

## Ключевые компоненты:

- **Runner** - изолированная среда выполнения jobs
- **Cache** - кэширование зависимостей между запусками  
- **Artifacts** - передача файлов между stages
- **Services** - вспомогательные сервисы для тестов
- **Environment** - целевые окружения для деплоя



```mermaid
sequenceDiagram
    participant D as Developer
    participant G as GitLab Server
    participant R as GitLab Runner
    participant C as Cache Storage
    participant S as Services (DB, Redis)
    participant E as External Environment

    Note over D,G: 1. Триггер Pipeline
    D->>G: git push / Merge Request
    G->>G: Обнаруживает .gitlab-ci.yml
    G->>G: Создает Pipeline (ID: $CI_PIPELINE_ID)
    G->>G: Парсит stages: build, test, deploy

    Note over G,R: 2. Планирование выполнения
    G->>R: Запрос на выполнение job (build)
    R->>R: Подготовка окружения
    R->>R: Pull docker image (node:16)
    R->>G: Клонирование репозитория
    R->>C: Восстановление cache (node_modules)

    Note over R,R: 3. Этап BUILD
    R->>R: Выполняет before_script (npm install)
    R->>R: Выполняет script (npm run build)
    R->>R: Сохраняет artifacts (dist/)
    R->>C: Обновляет cache
    R->>G: ✅ Job build успешно завершен

    G->>R: Запрос на выполнение job (test)
    R->>R: Pull docker image (node:16)
    R->>G: Клонирование репозитория
    R->>S: Запуск сервисов (PostgreSQL, Redis)
    
    Note over R,R: 4. Этап TEST
    R->>R: Восстанавливает artifacts из build
    R->>R: Выполняет тесты (npm test)
    R->>S: Тестовые запросы к БД и Redis
    R->>G: Загружает отчеты (junit.xml)
    R->>S: Останавливает сервисы
    R->>G: ✅ Job test успешно завершен

    G->>R: Запрос на выполнение job (deploy)
    R->>R: Pull docker image (alpine)
    
    Note over R,E: 5. Этап DEPLOY
    R->>E: SSH подключение к серверу
    R->>E: Копирование файлов (rsync/scp)
    R->>E: Запуск приложения (docker-compose up)
    E->>R: Подтверждение успешного деплоя
    R->>G: ✅ Job deploy успешно завершен
    R->>G: Обновляет environment status

    Note over G,D: 6. Завершение Pipeline
    G->>G: Обновляет статус Pipeline: ✅ SUCCESS
    G->>D: Уведомление: Pipeline passed
    G->>D: Отчет в Merge Request
    G->>D: Email уведомление
```

```mermaid
flowchart TB
    A[🚀 Developer: git push] --> B{GitLab Server}
    
    subgraph B [GitLab CI/CD Pipeline]
        C[Обнаружение .gitlab-ci.yml] --> D[Создание Pipeline]
        D --> E[Анализ stages]
        E --> F[Создание jobs queue]
    end
    
    subgraph G [Stage 1: BUILD]
        direction TB
        G1[Job: build] --> G2[📦 Docker: node:16]
        G2 --> G3[⚡ Восстановление cache]
        G3 --> G4[🛠️ npm install & build]
        G4 --> G5[💾 Сохранение artifacts]
    end
    
    subgraph H [Stage 2: TEST]
        direction TB
        H1[Job: test] --> H2[📦 Docker: node:16]
        H2 --> H3[🐘 Запуск PostgreSQL]
        H3 --> H4[🔴 Запуск Redis]
        H4 --> H5[📥 Загрузка artifacts]
        H5 --> H6[🧪 Выполнение тестов]
        H6 --> H7[📊 Генерация отчетов]
    end
    
    subgraph I [Stage 3: DEPLOY]
        direction TB
        I1[Job: deploy] --> I2[📦 Docker: alpine]
        I2 --> I3[🔐 SSH подключение]
        I3 --> I4[📤 Копирование файлов]
        I4 --> I5[🚀 Запуск приложения]
        I5 --> I6[🌐 Environment update]
    end
    
    F --> G
    G --> H
    H --> I
    
    I --> J[📝 Pipeline завершен]
    
    J --> K[✅ SUCCESS]
    J --> L[❌ FAILED]
    J --> M[⚠️ MANUAL]
    
    K --> N[📧 Уведомление разработчика]
    L --> N
    M --> O[⏸️ Ожидание ручного запуска]
    
    %% Связи с внешними сервисами
    G3 -.-> P[💽 Cache Storage]
    H3 -.-> Q[🐘 PostgreSQL Service]
    H4 -.-> R[🔴 Redis Service]
    I4 -.-> S[☁️ Production Server]
    
    style A fill:#ffeb3b
    style B fill:#e3f2fd
    style G fill:#e8f5e8
    style H fill:#fff3e0
    style I fill:#ffebee
    style J fill:#f3e5f5
    style K fill:#c8e6c9
    style L fill:#ffcdd2
    style M fill:#fff9c4
```


### Ключевые процессы:

- **Cache**: Восстановление зависимостей между запусками
- **Artifacts**: Передача файлов между этапами
- **Services**: Временные сервисы для тестирования
- **Environments**: Управление окружениями деплоя

