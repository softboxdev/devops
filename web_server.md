# Веб-сервер: принцип работы и диаграмма последовательностей

## 1. Общая архитектура веб-сервера

```mermaid
graph TB
    A[Клиент] --> B[Сетевой интерфейс]
    B --> C[Демон веб-сервера]
    
    subgraph "Ядро веб-сервера"
        D[Пул потоков/процессов]
        E[Парсер HTTP]
        F[Маршрутизатор]
        G[Обработчики запросов]
    end
    
    subgraph "Обработка запросов"
        H[Статические файлы]
        I[Динамический контент]
        J[Проксирование]
        K[Балансировка нагрузки]
    end
    
    subgraph "Внешние системы"
        L[Базы данных]
        M[Файловая система]
        N[Кэш]
        O[Внешние API]
    end
    
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    G --> I
    G --> J
    G --> K
    H --> M
    I --> L
    I --> O
    J --> N
```

## 2. Детальный процесс обработки HTTP запроса

```mermaid
sequenceDiagram
    participant C as Клиент (Browser)
    participant OS as ОС Сервера
    participant WS as Веб-сервер
    participant FS as Файловая система
    participant APP as Приложение
    participant DB as База данных

    Note over C,DB: 1. Установка соединения
    C->>OS: SYN - инициация TCP соединения
    OS->>C: SYN-ACK - подтверждение
    C->>OS: ACK - установка соединения
    OS->>WS: Новое соединение на порту 80/443
    
    Note over WS,WS: 2. Прием и парсинг запроса
    WS->>WS: Прием HTTP запроса из socket buffer
    WS->>WS: Парсинг HTTP заголовков
    WS->>WS: Декодирование URL и параметров
    WS->>WS: Проверка Virtual Host
    
    Note over WS,WS: 3. Анализ и маршрутизация
    WS->>WS: Определение типа запроса
    alt Запрос статического файла
        Note over WS,FS: 4.1 Обработка статического контента
        WS->>FS: Проверка существования файла
        FS->>WS: File metadata
        WS->>WS: Проверка прав доступа
        WS->>FS: Чтение файла
        FS->>WS: File content
        WS->>WS: Применение Gzip сжатия
        
    else Запрос динамического контента
        Note over WS,APP: 4.2 Обработка динамического контента
        WS->>APP: Передача запроса (FastCGI/WSGI)
        APP->>DB: SQL запросы
        DB->>APP: Данные из БД
        APP->>WS: Сгенерированный HTML
        
    else API запрос
        Note over WS,APP: 4.3 Обработка API
        WS->>APP: Передача JSON/XML данных
        APP->>WS: API response
        
    else Прокси запрос
        Note over WS,WS: 4.4 Проксирование
        WS->>WS: Forward на backend сервер
        WS->>WS: Получение ответа от backend
    end
    
    Note over WS,WS: 5. Формирование ответа
    WS->>WS: Сборка HTTP ответа
    WS->>WS: Установка заголовков (Cookies, Cache)
    WS->>WS: Применение фильтров (Gzip, SSI)
    
    Note over WS,C: 6. Отправка ответа
    WS->>OS: Запись в socket buffer
    OS->>C: Отправка TCP пакетов с данными
    C->>C: Рендеринг контента
    
    Note over WS,WS: 7. Завершение соединения
    alt Keep-Alive соединение
        WS->>WS: Сохранение соединения для следующих запросов
    else Close соединение
        WS->>OS: Закрытие socket
        OS->>C: FIN пакет
        C->>OS: ACK подтверждение
    end
```

## 3. Процесс работы с пулом потоков

```mermaid
sequenceDiagram
    participant C1 as Клиент 1
    participant C2 as Клиент 2
    participant C3 as Клиент 3
    participant L as Listener (Основной процесс)
    participant W1 as Worker 1
    participant W2 as Worker 2
    participant W3 as Worker 3
    participant FS as Файловая система

    Note over C1,FS: Инициализация сервера
    L->>L: Bind to port 80/443
    L->>W1: Fork worker process
    L->>W2: Fork worker process
    L->>W3: Fork worker process
    
    Note over C1,W1: Обработка множественных запросов
    C1->>L: HTTP Request 1
    L->>W1: Dispatch to available worker
    C2->>L: HTTP Request 2
    L->>W2: Dispatch to available worker
    C3->>L: HTTP Request 3
    L->>W3: Dispatch to available worker
    
    par Параллельная обработка
        W1->>FS: Read file1.html
        FS->>W1: File content
        W1->>C1: HTTP Response 1
    and
        W2->>FS: Read file2.css
        FS->>W2: File content
        W2->>C2: HTTP Response 2
    and
        W3->>FS: Read file3.js
        FS->>W3: File content
        W3->>C3: HTTP Response 3
    end
    
    Note over W1,W3: Мониторинг рабочих процессов
    L->>W1: Health check
    W1->>L: Worker status OK
    L->>W2: Health check
    W2->>L: Worker status OK
```

## 4. Обработка статических и динамических файлов

```mermaid
sequenceDiagram
    participant C as Клиент
    participant WS as Веб-сервер
    participant FS as Файловая система
    participant APP as Приложение
    participant DB as База данных

    C->>WS: GET /dashboard/user?id=123
    
    Note over WS,WS: Анализ запроса
    WS->>WS: Parse URL: /dashboard/user
    WS->>WS: Parse Query: id=123
    WS->>WS: Check file extension
    
    alt .html, .css, .js, .png файлы
        Note over WS,FS: Статический контент
        WS->>FS: Check file existence
        alt File exists
            FS->>WS: File metadata
            WS->>WS: Check cache headers
            WS->>FS: Read file content
            FS->>WS: File data
            WS->>C: HTTP 200 + content
        else File not exists
            WS->>C: HTTP 404 Not Found
        end
        
    else .php, .py, .rb файлы
        Note over WS,APP: Динамический контент
        WS->>APP: Forward via FastCGI/WSGI
        APP->>DB: Query: SELECT * FROM users WHERE id=123
        DB->>APP: User data
        APP->>APP: Generate HTML template
        APP->>WS: Rendered HTML
        WS->>C: HTTP 200 + dynamic content
        
    else API endpoints
        Note over WS,APP: API обработка
        WS->>APP: Forward API request
        APP->>DB: Multiple queries
        DB->>APP: Data sets
        APP->>APP: Format JSON response
        APP->>WS: JSON data
        WS->>C: HTTP 200 + JSON
    end
```

## 5. Процесс SSL/TLS обработки

```mermaid
sequenceDiagram
    participant C as Клиент
    participant WS as Веб-сервер
    participant CA as Certificate Authority

    Note over C,CA: TLS Handshake процесс
    C->>WS: ClientHello (supported ciphers)
    WS->>C: ServerHello (selected cipher) + Certificate
    C->>CA: Verify certificate (optional)
    CA->>C: Certificate valid
    
    alt TLS 1.2
        C->>WS: ClientKeyExchange (pre-master secret)
        WS->>C: ChangeCipherSpec (switch to encrypted)
        C->>WS: Finished (encrypted handshake)
        WS->>C: Finished (encrypted handshake)
    else TLS 1.3
        C->>WS: ClientKeyExchange + Finished
        WS->>C: Finished
    end
    
    Note over C,WS: Зашифрованная коммуникация
    C->>WS: Encrypted HTTP Request
    WS->>WS: Decrypt request
    WS->>WS: Process business logic
    WS->>WS: Encrypt response
    WS->>C: Encrypted HTTP Response
    
    Note over WS,WS: Сессия и возобновление
    WS->>WS: Store session ticket
    C->>WS: Session resume request
    WS->>C: Resumed session (optimized handshake)
```

## 6. Кэширование и оптимизация

```mermaid
sequenceDiagram
    participant C as Клиент
    participant WS as Веб-сервер
    participant CACHE as Кэш
    participant FS as Файловая система
    participant APP as Приложение

    C->>WS: GET /page.html
    
    Note over WS,CACHE: Проверка кэша
    WS->>CACHE: Check cache key for /page.html
    alt Cache HIT
        CACHE->>WS: Cached content + headers
        WS->>C: HTTP 200 (from cache)
        
    else Cache MISS
        WS->>FS: Read /page.html from disk
        FS->>WS: File content
        
        Note over WS,CACHE: Сохранение в кэш
        WS->>CACHE: Store content with TTL
        CACHE->>WS: Cache stored
        
        WS->>C: HTTP 200 (fresh content)
    end
    
    Note over C,WS: Conditional requests
    C->>WS: GET /style.css with If-Modified-Since
    WS->>FS: Check file modification time
    FS->>WS: Last modified date
    alt Not modified
        WS->>C: HTTP 304 Not Modified
    else Modified
        WS->>FS: Read fresh content
        FS->>WS: New file content
        WS->>C: HTTP 200 with new content
    end
```

## 7. Обработка ошибок и мониторинг

```mermaid
sequenceDiagram
    participant C as Клиент
    participant WS as Веб-сервер
    participant LOG as Система логов
    participant MON as Мониторинг
    participant ADMIN as Администратор

    C->>WS: GET /non-existent-page
    
    Note over WS,WS: Обнаружение ошибки
    WS->>WS: File not found
    WS->>WS: Generate 404 error page
    WS->>C: HTTP 404 Not Found
    
    Note over WS,LOG: Логирование
    WS->>LOG: Log error: 404 - /non-existent-page
    LOG->>MON: Send metrics
    
    Note over MON,ADMIN: Оповещение
    MON->>MON: Analyze error rate
    alt High error rate
        MON->>ADMIN: Alert: High 404 rate detected
        ADMIN->>WS: Investigate and fix
    end
    
    Note over WS,WS: Graceful error handling
    C->>WS: Invalid HTTP request
    WS->>WS: Parse error
    WS->>C: HTTP 400 Bad Request
    WS->>LOG: Log invalid request
```

## Ключевые принципы работы веб-сервера:

1. **Мультиплексирование** - обработка множества соединений в одном процессе
2. **Неблокирующие операции** - асинхронная обработка I/O
3. **Пул рабочих процессов** - распределение нагрузки
4. **Кэширование** - оптимизация повторяющихся запросов
5. **Виртуальные хосты** - обслуживание множества доменов
6. **Безопасность** - защита от атак и уязвимостей
7. **Масштабируемость** - обработка растущей нагрузки

