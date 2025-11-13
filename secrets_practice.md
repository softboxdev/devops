
# 🎯 Подробное объяснение Сервисов, ConfigMaps и Secrets

## 🏢 Аналогия: Представим что Kubernetes - это большой офисный центр

**Давайте представим:**
- **Pod** = Комната с сотрудниками (ваше приложение)
- **Service** = Секретарь на reception
- **ConfigMap** = Инструкции и правила офиса
- **Secret** = Сейф с паролями и ключами

## 1. 🚪 Что такое Сервисы (Services)?

### 🤔 Простыми словами:

**Сервис - это "постоянный телефонный номер" для вашего приложения**, который:
- Не меняется когда сотрудники (Pod) переезжают в другие комнаты
- Знает где найти нужного сотрудника в любой момент
- Принимает звонки и соединяет с правильным человеком

### 📖 Техническое определение:

**Service** - это абстракция которая определяет логический набор Pod и политику доступа к ним. Сервис обеспечивает постоянную точку доступа к приложению.

### 🎯 Зачем нужны Сервисы?

**Без Service:**
```bash
"Мне нужен Петя из отдела разработки"
"Ой, Петя сегодня в комнате 305" 
*Завтра Петя переехал в комнату 412*
"Где теперь Петя? Я его потерял!"
```

**С Service:**
```bash
"Мне нужен отдел разработки"
"Звоните по номеру 555-DEVELOP"
*Неважно где сидит Петя - всегда соединят с отделом разработки*
```

### 🛠️ Типы Сервисов:

#### 1. **ClusterIP** (Внутренний телефон)
- 📞 **Работает только внутри офиса** (кластера)
- 🔒 **Недоступен снаружи**
- 💡 **Идеально для внутреннего общения между сервисами**

```yaml
# Как выглядит внутренний телефон
apiVersion: v1
kind: Service
metadata:
  name: internal-phone
spec:
  type: ClusterIP  # Только внутри офиса
  selector:
    app: backend   # Соединяет с backend отделом
  ports:
  - port: 80       # Номер для звонков
    targetPort: 8080  # На какой порт сотрудников соединять
```

#### 2. **NodePort** (Общий телефон на reception)
- 📞 **Работает внутри и снаружи офиса**
- 🔓 **Доступен по специальному номеру** (30000-32767)
- 💡 **Идеально для тестирования и доступа снаружи**

```yaml
# Как выглядит телефон на reception
apiVersion: v1
kind: Service
metadata:
  name: reception-phone
spec:
  type: NodePort   # Можно звонить снаружи
  selector:
    app: frontend  # Соединяет с frontend отделом
  ports:
  - port: 80       # Внутренний номер
    targetPort: 80 # Порту сотрудников
    nodePort: 30080 # Номер для звонков снаружи
```

#### 3. **LoadBalancer** (Автоответчик с несколькими линиями)
- 📞 **Автоматически создает внешний балансировщик** (в облаке)
- 🌐 **Получает внешний IP адрес**
- 💰 **Обычно платный** (в облачных провайдерах)

### 🎯 Как работают Сервисы на практике:

```
[ Внешний клиент ]
       ↓
[ Service: NodePort :30080 ] ← Постоянный номер
       ↓
[ Pod: frontend-abc123 ] ← Может быть удален
[ Pod: frontend-def456 ] ← Может быть создан
[ Pod: frontend-ghi789 ] ← Балансировка нагрузки
```

### 💡 Пример запроса:
```bash
# Клиент звонит по постоянному номеру
curl http://office-building:30080

# Service соединяет с одним из доступных Pod
# → frontend-abc123: "Привет, я frontend-abc123!"
# → frontend-def456: "Привет, я frontend-def456!"
```

## 2. 📁 Что такое ConfigMaps?

### 🤔 Простыми словами:

**ConfigMap - это "папка с инструкциями и настройками"** которая:
- Хранит конфигурации отдельно от кода приложения
- Позволяет менять настройки без пересборки приложения
- Может содержать целые файлы конфигурации

### 📖 Техническое определение:

**ConfigMap** - это API объект используемый для хранения неконфиденциальных данных в формате ключ-значение. Pod могут использовать ConfigMap как переменные окружения, аргументы командной строки или файлы конфигурации.

### 🎯 Зачем нужны ConfigMaps?

**Без ConfigMap:**
```bash
# Настройки зашиты в приложение
app.config = "production"
db.host = "localhost"

# Чтобы поменять на staging - нужно пересобирать приложение!
```

**С ConfigMap:**
```bash
# Настройки хранятся отдельно
app.config = "{{ .ConfigMap.app.environment }}"
db.host = "{{ .ConfigMap.database.host }}"

# Меняем ConfigMap → настройки обновляются автоматически
```

### 🛠️ Способы использования ConfigMap:

#### 1. **Как переменные окружения** (Environment Variables)
```yaml
# ConfigMap - наша папка с настройками
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-settings
data:
  APP_ENV: "production"      # Простые настройки
  DB_HOST: "postgresql"
  LOG_LEVEL: "INFO"
  APP_NAME: "My Cool App"
```

```yaml
# Pod использует настройки как переменные
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: my-app:1.0
    env:
    - name: APPLICATION_ENV  # Имя переменной в Pod
      valueFrom:
        configMapKeyRef:
          name: app-settings # Берем из ConfigMap
          key: APP_ENV       # Ключ откуда брать значение
```

#### 2. **Как файлы конфигурации** (Config Files)
```yaml
# ConfigMap с целыми файлами
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-files
data:
  # Простой key-value
  application.properties: |
    app.name=My Application
    app.version=1.0.0
    server.port=8080
    database.host=postgresql-service
    
  # Цельный файл конфигурации
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        
        location /api {
            proxy_pass http://backend-service;
        }
    }
```

```yaml
# Pod монтирует ConfigMap как файлы
apiVersion: v1
kind: Pod
metadata:
  name: web-server
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d  # Куда положить файлы
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: app-config-files  # Какие файлы брать
```

### 🎯 Преимущества ConfigMap:

1. **Отделение конфигурации от кода**
2. **Единое место для настроек**
3. **Возможность горячего обновления** (в некоторых случаях)
4. **Версионирование конфигураций**
5. **Разные настройки для разных окружений**

## 3. 🔐 Что такое Secrets?

### 🤔 Простыми словами:

**Secret - это "сейф с важными документами"** который:
- Хранит пароли, ключи, токены
- Более безопасен чем ConfigMap (но не полностью!)
- Данные хранятся в закодированном виде (base64)

### 📖 Техническое определение:

**Secret** - это объект содержащий небольшой объем конфиденциальных данных, таких как пароли, токены или ключи. Информация в Secret хранится в base64 кодировке.

### ⚠️ Важное предупреждение:

**Secrets НЕ полностью безопасны!**
- Они только base64 encoded (не зашифрованы!)
- Лучше использовать внешние системы типа HashiCorp Vault
- Но лучше чем хранить пароли в ConfigMap!

### 🎯 Зачем нужны Secrets?

**Без Secret:**
```yaml
# Пароль в ConfigMap - ОПАСНО!
apiVersion: v1
kind: ConfigMap
metadata:
  name: dangerous-config
data:
  DB_PASSWORD: "super-secret-password"  # Видно всем!
```

**С Secret:**
```yaml
# Пароль в Secret - безопаснее
apiVersion: v1
kind: Secret
metadata:
  name: safe-secret
type: Opaque
data:
  # Закодировано в base64
  DB_PASSWORD: c3VwZXItc2VjcmV0LXBhc3N3b3Jk
```

### 🛠️ Создание Secrets:

#### 1. **Создание из literal значений**
```bash
# Kubernetes сам закодирует в base64
kubectl create secret generic app-secrets \
  --from-literal=db-password="my-secret-password" \
  --from-literal=api-token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
```

#### 2. **Создание из файлов**
```bash
# Создаем файлы с секретами
echo "postgres://user:pass@localhost/mydb" > database.url
echo "secret-jwt-key" > jwt.secret

# Создаем secret из файлов
kubectl create secret generic app-secrets-files \
  --from-file=./database.url \
  --from-file=./jwt.secret
```

#### 3. **Создание через YAML** (данные уже в base64)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: manual-secret
type: Opaque
data:
  # ДАННЫЕ ДОЛЖНЫ БЫТЬ В BASE64!
  database-password: bXktc2VjcmV0LXBhc3N3b3JkMTIz
  api-key: ZXlKaGJHY2lPaUpJVXpJMU5pSXNJbXRwWkNJNklqSXVOekExTmpJaUxDSmpiR0Z6Y3lJNklrMWxiV0psYzJGMGFXOXVJaXdpYzI5MWNtTmxjME52Ym5SbGJuUWlPaUpsYldGcGJFSnZjbVJsY21GdWFTRnNiSGtnT2lKMWNtd2lMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwzZDNkeTUzTXk1dmNtY3ZNVGs1T1M5amNtVmtaVzUwY3k5cGJXOXlkQzVqYjIwaUxDSnBZWFFpT2pFMk5UY3dNak0xTlRjc0ltVjRjQ0k2TVRZMU1UY3dOekUzTkN3aVpYaHdJam94TlRjMU1UVTJORFF4TENKcGMzTWlPaUpvZEhSd2N6b3ZMM2QzZHk1M015NXZjbWN2TVRBeUx6RTVMekU1SVM1emJHbGpZV3d1WjI5dloyeGxMbU52YlNJc0luQnliM1psYzNCdmFXNW5Jam9pYzI5MWNtTmxjME52Ym5SbGJuUWlMQ0p3Y205bWFXeGxYMmxrSWpvaU1UQXlNVEV5TURFeU1pNHdNQzR4TlRZaWZRLmV5SmhlU0k2SW1Oc2FXVnVkRU5oY210dmJtOXVaU0lzSW1Gc1p5STZJbUZ6WTI5dGNHRnllVDBpTENKcFlYUWlPakUxTlRjMU5UYzVNakI5Lk15U2VjcmV0S2V5" 
```

### 🔧 Использование Secrets в Pod:

#### 1. **Как переменные окружения**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets
spec:
  containers:
  - name: app
    image: my-app:1.0
    env:
    - name: DATABASE_PASSWORD  # Имя переменной
      valueFrom:
        secretKeyRef:
          name: app-secrets    # Имя Secret
          key: db-password     # Ключ в Secret
```

#### 2. **Как файлы** (часто используется для SSL сертификатов)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secret-files
spec:
  containers:
  - name: app
    image: my-app:1.0
    volumeMounts:
    - name: secret-volume
      mountPath: "/etc/secrets"
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: app-secrets  # Secret для монтирования
```

### 🎯 Разница между ConfigMap и Secret:

| Характеристика | ConfigMap | Secret |
|----------------|-----------|---------|
| **Назначение** | Обычные настройки | Секретные данные |
| **Кодировка** | Plain text | Base64 encoded |
| **Безопасность** | Низкая | Средняя (не полное шифрование) |
| **Примеры** | URL, порты, настройки | Пароли, токены, ключи |

## 4. 🏗️ Полная архитектура работы

### 🎯 Как всё работает вместе:

```
[ ВНЕШНИЙ МИР ]
       ↓
[ Service: NodePort ] ← Постоянный номер 30080
       ↓
[ Pod: frontend-pod ] ← Ваше приложение
       ↓
[ ConfigMap ] ← Настройки приложения
       ↓  
[ Secret ] ← Пароли и ключи
       ↓
[ Service: ClusterIP ] ← Внутренняя связь
       ↓
[ Pod: backend-pod ] ← Другое приложение
```

### 💡 Реальный пример:

```yaml
# 1. ConfigMap с настройками
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_NAME: "My Online Store"
  MAX_USERS: "1000"
  FEATURE_FLAGS: "new_ui,advanced_search"

---
# 2. Secret с паролями  
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
data:
  db-password: cG9zdGdyZXMtcGFzc3dvcmQ=
  api-key: bXktYXBpLWtleS0xMjM=

---
# 3. Service для доступа
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080

---
# 4. Pod который использует всё
apiVersion: v1
kind: Pod
metadata:
  name: webapp-pod
  labels:
    app: webapp
spec:
  containers:
  - name: webapp
    image: my-app:1.0
    ports:
    - containerPort: 8080
    env:
    # Переменные из ConfigMap
    - name: APPLICATION_NAME
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_NAME
    # Переменные из Secret
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db-password
```

## 5. 🎓 Обучение через аналогии

### 🏢 Офисный центр (продолжение):

- **Pod** = Комната с сотрудниками
- **Service: ClusterIP** = Внутренний телефон (только для сотрудников)
- **Service: NodePort** = Телефон на reception (можно звонить снаружи)
- **ConfigMap** = Папка с инструкциями офиса (расписание, правила)
- **Secret** = Сейф с паролями от компьютеров и ключами от кабинетов

### 🏠 Жилой дом:

- **Pod** = Квартира в доме
- **Service: ClusterIP** = Домофон (только для жильцов)
- **Service: NodePort** = Код от ворот (знают все)
- **ConfigMap** = Объявления на доске (расписание уборки, правила)
- **Secret** = Ключи от подвала и коды от сигнализации

### 🚗 Таксопарк:

- **Pod** = Конкретная машина такси
- **Service: ClusterIP** = Рация между диспетчером и водителями
- **Service: NodePort** = Номер телефона таксопарка
- **ConfigMap** = Тарифы, зоны работы, правила
- **Secret** = Пароли от банковских терминалов, ключи от машин

## 6. 💡 Ключевые преимущества

### 🎯 Сервисы дают:

1. **Постоянство** - один адрес на всю жизнь приложения
2. **Балансировка** - автоматическое распределение нагрузки
3. **Обнаружение** - автоматическое нахождение Pod
4. **Изоляция** - внутренние и внешние точки доступа

### 🎯 ConfigMaps дают:

1. **Гибкость** - настройки отдельно от кода
2. **Централизация** - все настройки в одном месте
3. **Версионирование** - можно отслеживать изменения настроек
4. **Многократное использование** - одни настройки для многих Pod

### 🎯 Secrets дают:

1. **Безопасность** - лучше чем пароли в коде
2. **Управление** - централизованное хранение секретов
3. **Ротация** - легче менять пароли
4. **Аудит** - можно отслеживать кто использует секреты

## 7. 🚨 Частые ошибки новичков

### ❌ "Сервис не находит Pod!"

**Проверьте:**
- Метки (labels) в Pod совпадают с selector в Service
- Pod действительно запущены и готовы (`kubectl get pods`)
- Правильно указаны порты

### ❌ "ConfigMap не применяется!"

**Проверьте:**
- ConfigMap создан в том же namespace что и Pod
- Правильно указаны имена в configMapKeyRef
- Pod перезапущен после изменения ConfigMap

### ❌ "Secret показывает странные символы!"

**Это нормально:**
- Secret хранит данные в base64
- При использовании в Pod они декодируются автоматически
- Для просмотра: `kubectl get secret name -o jsonpath='{.data.key}' | base64 --decode`

## 8. 🎯 Итоговое понимание

### После этого объяснения вы должны понимать что:

1. **Service** = Постоянный телефонный номер для вашего приложения
2. **ClusterIP** = Внутренний телефон (только внутри компании)
3. **NodePort** = Общий телефон (можно звонить снаружи)
4. **ConfigMap** = Папка с настройками и инструкциями
5. **Secret** = Сейф с паролями и важными документами

### 💪 Теперь когда вы понимаете концепции:

- **Service** - это не магия, а просто "телефонная книга" для Pod
- **ConfigMap** - это "блокнот с настройками" который можно менять
- **Secret** - это "сейф" который немного безопаснее чем открытый текст
- **Всё вместе** - это мощная система для управления приложениями

# Практическое руководство по Kubernetes на Ubuntu 24.04 с 4 ГБ ОЗУ

## Подготовка окружения

### 1. Установка MicroK8s

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка MicroK8s (самый легковесный вариант для 4 ГБ ОЗУ)
sudo snap install microk8s --classic

# Добавление пользователя в группу microk8s
sudo usermod -a -G microk8s $USER
newgrp microk8s

# Включение необходимых дополнений
microk8s enable dns storage registry
```

### 2. Настройка для ограниченной памяти

```bash
# Создание конфигурационного файла для ограничения ресурсов
sudo tee /var/snap/microk8s/current/args/containerd-template.toml > /dev/null <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "overlayfs"
  default_runtime_name = "runc"
  
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
    runtime_type = "io.containerd.runc.v2"
    
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
    
[plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]
  runtime_type = "io.containerd.runtime.v1.linux"
  
[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/var/snap/microk8s/current/opt/cni/bin"
  conf_dir = "/var/snap/microk8s/current/args/cni-network"
EOF

# Перезапуск MicroK8s
microk8s stop
microk8s start
```

## Упражнение 1: Создание оптимизированных Pod'ов

### Простейший Pod с ограничениями памяти

```yaml
# simple-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-optimized
  labels:
    app: nginx
spec:
  containers:
  - name: nginx-container
    image: nginx:alpine  # Используем легковесный образ
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
```

Применяем конфигурацию:
```bash
microk8s kubectl apply -f simple-pod.yaml
```

### Проверка состояния Pod'а

```bash
# Проверить статус pod'а
microk8s kubectl get pods

# Подробная информация о pod'е
microk8s kubectl describe pod nginx-optimized

# Проверить использование ресурсов
microk8s kubectl top pod nginx-optimized
```

## Упражнение 2: Создание сервисов

### 1. Сервис типа ClusterIP

```yaml
# clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-clusterip
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
```

### 2. Сервис типа NodePort

```yaml
# nodeport-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
    protocol: TCP
```

Применяем сервисы:
```bash
microk8s kubectl apply -f clusterip-service.yaml
microk8s kubectl apply -f nodeport-service.yaml
```

### Проверка сервисов

```bash
# Показать все сервисы
microk8s kubectl get services

# Проверить доступность через NodePort
curl http://localhost:30080
```

## Упражнение 3: Работа с ConfigMap

### Создание ConfigMap

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Простые ключ-значение
  APP_NAME: "My Application"
  ENVIRONMENT: "development"
  LOG_LEVEL: "INFO"
  
  # Конфигурационный файл
  nginx-config.conf: |
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
        }
    }
```

### Pod с использованием ConfigMap через переменные окружения

```yaml
# pod-with-configmap-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-config-env
spec:
  containers:
  - name: app-container
    image: busybox:latest
    command: ['sh', '-c', 'echo "App: $APP_NAME, Env: $ENVIRONMENT, Log: $LOG_LEVEL" && sleep 3600']
    env:
    - name: APP_NAME
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: APP_NAME
    - name: ENVIRONMENT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: ENVIRONMENT
    - name: LOG_LEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: LOG_LEVEL
    resources:
      requests:
        memory: "32Mi"
        cpu: "10m"
      limits:
        memory: "64Mi"
        cpu: "50m"
```

### Pod с использованием ConfigMap через файлы

```yaml
# pod-with-configmap-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-with-config
spec:
  containers:
  - name: nginx-container
    image: nginx:alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: config-volume
      mountPath: /etc/nginx/conf.d
      readOnly: true
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
  volumes:
  - name: config-volume
    configMap:
      name: app-config
      items:
      - key: nginx-config.conf
        path: default.conf
```

Применяем ConfigMap и Pod'ы:
```bash
microk8s kubectl apply -f configmap.yaml
microk8s kubectl apply -f pod-with-configmap-env.yaml
microk8s kubectl apply -f pod-with-configmap-volume.yaml
```

## Упражнение 4: Работа с Secrets

### Создание Secrets

#### Способ 1: Создание через командную строку

```bash
# Создание secret с данными в кодировке base64
echo -n 'my-secret-username' | base64
echo -n 'my-secret-password' | base64

# Создание secret через kubectl
microk8s kubectl create secret generic app-secrets \
  --from-literal=username=my-secret-username \
  --from-literal=password=my-secret-password
```

#### Способ 2: Создание через YAML файл

```yaml
# secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets-yaml
type: Opaque
data:
  # Данные должны быть в base64
  database-url: bXlzcWw6Ly9kYjoxMjM0NTZAbG9jYWxob3N0L2FwcA==
  api-key: YXBpLWtleS1zZWNyZXQtdmFsdWU=
```

### Pod с использованием Secrets через переменные окружения

```yaml
# pod-with-secrets-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets-env
spec:
  containers:
  - name: app-container
    image: busybox:latest
    command: ['sh', '-c', 'echo "User: $DB_USERNAME, Pass: $DB_PASSWORD" && sleep 3600']
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: password
    resources:
      requests:
        memory: "32Mi"
        cpu: "10m"
      limits:
        memory: "64Mi"
        cpu: "50m"
```

### Pod с использованием Secrets через файлы

```yaml
# pod-with-secrets-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-secrets-volume
spec:
  containers:
  - name: app-container
    image: busybox:latest
    command: ['sh', '-c', 'ls -la /etc/secrets/ && cat /etc/secrets/username && sleep 3600']
    volumeMounts:
    - name: secrets-volume
      mountPath: /etc/secrets
      readOnly: true
    resources:
      requests:
        memory: "32Mi"
        cpu: "10m"
      limits:
        memory: "64Mi"
        cpu: "50m"
  volumes:
  - name: secrets-volume
    secret:
      secretName: app-secrets
```

Применяем Secrets и Pod'ы:
```bash
microk8s kubectl apply -f secrets.yaml
microk8s kubectl apply -f pod-with-secrets-env.yaml
microk8s kubectl apply -f pod-with-secrets-volume.yaml
```

## Упражнение 5: Комплексный пример - Приложение с ConfigMap и Secrets

```yaml
# complete-app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-app-config
data:
  config.js: |
    window.APP_CONFIG = {
      apiUrl: "/api/v1",
      features: {
        analytics: true,
        notifications: false
      }
    }
---
apiVersion: v1
kind: Secret
metadata:
  name: web-app-secrets
type: Opaque
data:
  # echo -n 'production-db' | base64
  db-name: cHJvZHVjdGlvbi1kYg==
  # echo -n 'secret-api-key-123' | base64
  api-secret: c2VjcmV0LWFwaS1rZXktMTIz
---
apiVersion: v1
kind: Pod
metadata:
  name: complete-web-app
  labels:
    app: web-app
spec:
  containers:
  - name: web-container
    image: nginx:alpine
    ports:
    - containerPort: 80
    env:
    - name: DATABASE_NAME
      valueFrom:
        secretKeyRef:
          name: web-app-secrets
          key: db-name
    - name: API_SECRET
      valueFrom:
        secretKeyRef:
          name: web-app-secrets
          key: api-secret
    volumeMounts:
    - name: config-volume
      mountPath: /usr/share/nginx/html/config.js
      subPath: config.js
    - name: secrets-volume
      mountPath: /etc/app-secrets
      readOnly: true
    resources:
      requests:
        memory: "96Mi"
        cpu: "100m"
      limits:
        memory: "192Mi"
        cpu: "200m"
  volumes:
  - name: config-volume
    configMap:
      name: web-app-config
      items:
      - key: config.js
        path: config.js
  - name: secrets-volume
    secret:
      secretName: web-app-secrets
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
spec:
  type: NodePort
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
```

Применяем комплексное приложение:
```bash
microk8s kubectl apply -f complete-app.yaml
```

## Полезные команды для мониторинга и отладки

```bash
# Просмотр всех ресурсов
microk8s kubectl get all

# Просмотр логов pod'а
microk8s kubectl logs nginx-optimized

# Интерактивный терминал в pod'е
microk8s kubectl exec -it nginx-optimized -- /bin/sh

# Проверка использования ресурсов
microk8s kubectl top pods
microk8s kubectl top nodes

# Описание ресурса для отладки
microk8s kubectl describe pod nginx-optimized

# Проверка событий кластера
microk8s kubectl get events --sort-by=.metadata.creationTimestamp
```

## Оптимизации для системы с 4 ГБ ОЗУ

### 1. Ограничение ресурсов MicroK8s

```bash
# Создание конфигурационного файла для ограничения памяти
sudo tee /var/snap/microk8s/current/args/kubelet > /dev/null <<EOF
--container-runtime=remote
--container-runtime-endpoint=unix:///var/snap/microk8s/common/run/containerd.sock
--kubeconfig=/var/snap/microk8s/current/credentials/kubelet.config
--cert-dir=/var/snap/microk8s/current/certs/kubelet
--client-ca-file=/var/snap/microk8s/current/certs/ca.crt
--anonymous-auth=false
--network-plugin=cni
--cni-conf-dir=/var/snap/microk8s/current/args/cni-network
--cni-bin-dir=/var/snap/microk8s/current/opt/cni/bin
--cluster-dns=10.152.183.10
--cluster-domain=cluster.local
--fail-swap-on=false
--eviction-hard=memory.available<100Mi,nodefs.available<1Gi,imagefs.available<1Gi
--eviction-soft=memory.available<300Mi
--eviction-soft-grace-period=memory.available=2m
--max-pods=50
--system-reserved=memory=500Mi,cpu=250m
--kube-reserved=memory=500Mi,cpu=250m
EOF
```

### 2. Очистка ресурсов

```bash
# Удаление всех созданных ресурсов
microk8s kubectl delete --all pods,services,configmaps,secrets

# Остановка MicroK8s при необходимости
microk8s stop

# Очистка дискового пространства
microk8s reset
```

Следующее задание выполните самостоятельно выделив оптимизированные ресурсы под ваш тип машины, согласно изученным методам выше.

# 🚀 Практическое руководство по Kubernetes: Сервисы, ConfigMaps и Secrets

## 📋 Предварительная настройка

### 1. Запуск Minikube на Ubuntu 24.04

```bash
# Запускаем Minikube с дополнительными функциями
minikube start --memory=4096 --cpus=2 --addons=ingress

# Проверяем
kubectl get nodes
minikube status

# Создаем рабочую директорию
mkdir ~/k8s-services-practice && cd ~/k8s-services-practice
```

### 2. Подготовка тестового приложения

**Создаем простое веб-приложение:**
```bash
# Создаем Dockerfile для нашего тестового приложения
cat > Dockerfile << EOF
FROM nginx:1.25-alpine
COPY index.html /usr/share/nginx/html/
COPY config.js /usr/share/nginx/html/
EOF

# Создаем HTML страницу
cat > index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>K8s Practice App</title>
    <script src="config.js"></script>
</head>
<body>
    <h1>Welcome to Kubernetes Practice!</h1>
    <div id="config"></div>
    <script>
        document.getElementById('config').innerHTML = 
            '<p>App Version: ' + APP_VERSION + '</p>' +
            '<p>Environment: ' + ENVIRONMENT + '</p>' +
            '<p>API URL: ' + API_URL + '</p>';
    </script>
</body>
</html>
EOF

# Создаем JS файл который будем менять через ConfigMap
cat > config.js << EOF
// This file will be replaced by ConfigMap
const APP_VERSION = '1.0.0';
const ENVIRONMENT = 'development';
const API_URL = 'http://localhost:8080';
EOF
```

---

## 🌐 ЧАСТЬ 1: Сервисы (Services)

### 🎯 Задание 1.1: Подготовка Deployment для экспериментов

**1. Создаем Deployment веб-приложения:**
```yaml
# deployment-web.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
      tier: frontend
  template:
    metadata:
      labels:
        app: web
        tier: frontend
        version: "1.0"
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
```

```bash
kubectl apply -f deployment-web.yaml
kubectl get pods -l app=web
```

### 🎯 Задание 1.2: Сервис типа ClusterIP

**Теория:**
- **ClusterIP**: Внутренний IP, доступен только внутри кластера
- Балансирует нагрузку между Pod
- Автоматически обнаруживает новые Pod

**1. Создаем ClusterIP сервис:**
```yaml
# service-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-clusterip
  labels:
    app: web
spec:
  type: ClusterIP
  selector:
    app: web
    tier: frontend
  ports:
  - name: http
    port: 80          # Порт сервиса
    targetPort: 80    # Порт контейнера
    protocol: TCP
```

**2. Применяем и тестируем:**
```bash
kubectl apply -f service-clusterip.yaml

# Смотрим сервис
kubectl get service web-service-clusterip
kubectl describe service web-service-clusterip

# Тестируем изнутри кластера
kubectl run test-pod --image=alpine:3.18 --rm -it --restart=Never -- sh

# Внутри test-pod:
apk add curl
curl http://web-service-clusterip
exit
```

**3. Упражнение: Поиск эндпоинтов**
```bash
# Какие Pod обслуживает сервис?
kubectl get endpoints web-service-clusterip

# Детальная информация
kubectl describe endpoints web-service-clusterip
```

### 🎯 Задание 1.3: Сервис типа NodePort

**Теория:**
- **NodePort**: Открывает порт на всех узлах кластера
- Доступен извне кластера
- Диапазон портов: 30000-32767

**1. Создаем NodePort сервис:**
```yaml
# service-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-nodeport
  labels:
    app: web
spec:
  type: NodePort
  selector:
    app: web
    tier: frontend
  ports:
  - name: http
    port: 80          # Внутренний порт сервиса
    targetPort: 80    # Порт контейнера
    nodePort: 30080   # Внешний порт (опционально)
    protocol: TCP
```

**2. Применяем и тестируем:**
```bash
kubectl apply -f service-nodeport.yaml

# Смотрим сервис
kubectl get service web-service-nodeport

# Получаем IP Minikube
minikube ip

# Тестируем из браузера или curl
curl http://$(minikube ip):30080

# Или открываем в браузере
minikube service web-service-nodeport --url
```

**3. Упражнение: Автоматический NodePort**
```yaml
# service-nodeport-auto.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service-nodeport-auto
spec:
  type: NodePort
  selector:
    app: web
    tier: frontend
  ports:
  - name: http
    port: 80
    targetPort: 80
    # nodePort не указан - Kubernetes выберет автоматически
```

```bash
kubectl apply -f service-nodeport-auto.yaml
kubectl get service web-service-nodeport-auto
# Какой порт назначил Kubernetes?
```

### 🎯 Задание 1.4: Сравнение и использование сервисов

**1. Создаем тестовое приложение для сравнения:**
```yaml
# deployment-api.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
      tier: backend
  template:
    metadata:
      labels:
        app: api
        tier: backend
    spec:
      containers:
      - name: api
        image: containous/whoami  # Простое приложение которое возвращает информацию
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
```

**2. Создаем оба типа сервисов для API:**
```yaml
# api-services.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service-clusterip
spec:
  type: ClusterIP
  selector:
    app: api
    tier: backend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-service-nodeport
spec:
  type: NodePort
  selector:
    app: api
    tier: backend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
```

**3. Тестируем доступность:**
```bash
kubectl apply -f deployment-api.yaml -f api-services.yaml

# Тестируем ClusterIP изнутри кластера
kubectl run test-clusterip --image=alpine:3.18 --rm -it --restart=Never -- sh
curl http://api-service-clusterip
exit

# Тестируем NodePort снаружи
curl http://$(minikube ip):30081

# Смотрим все сервисы
kubectl get services
```

---

## 📁 ЧАСТЬ 2: ConfigMaps

### 🎯 Задание 2.1: Создание ConfigMap разными способами

**Теория:**
- ConfigMap хранит конфигурационные данные
- Может подключаться как переменные окружения или файлы
- Не предназначен для хранения секретных данных

**1. Способ 1: Из файла**
```bash
# Создаем конфигурационные файлы
echo "production" > environment.txt
echo "2.1.0" > version.txt
echo "https://api.myapp.com" > api_url.txt

# Создаем ConfigMap из файлов
kubectl create configmap app-config --from-file=./environment.txt --from-file=./version.txt --from-file=./api_url.txt

# Проверяем
kubectl get configmap app-config
kubectl describe configmap app-config
```

**2. Способ 2: Из literal значений**
```bash
kubectl create configmap app-config-literal \
  --from-literal=APP_NAME="My Application" \
  --from-literal=APP_ENV="staging" \
  --from-literal=LOG_LEVEL="DEBUG" \
  --from-literal=MAX_CONNECTIONS="100"

kubectl get configmap app-config-literal -o yaml
```

**3. Способ 3: Из YAML файла**
```yaml
# configmap-manual.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-manual
  labels:
    app: web
data:
  # Простые ключ-значение
  app.name: "Kubernetes Practice App"
  app.version: "1.0.0"
  environment: "production"
  
  # Конфигурация как многострочная строка
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;
        
        location /health {
            return 200 "healthy\n";
        }
    }
  
  # JSON конфигурация
  config.json: |
    {
      "database": {
        "host": "localhost",
        "port": 5432
      },
      "features": {
        "auth": true,
        "cache": false
      }
    }
```

```bash
kubectl apply -f configmap-manual.yaml
kubectl get configmap app-config-manual -o yaml
```

### 🎯 Задание 2.2: Подключение ConfigMap как переменных окружения

**1. Создаем Deployment с переменными из ConfigMap:**
```yaml
# deployment-with-env.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-config
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-with-config
  template:
    metadata:
      labels:
        app: app-with-config
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        env:
        # Отдельные переменные из ConfigMap
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: app-config-manual
              key: app.name
        - name: APP_VERSION
          valueFrom:
            configMapKeyRef:
              name: app-config-manual
              key: app.version
        - name: ENVIRONMENT
          valueFrom:
            configMapKeyRef:
              name: app-config-manual
              key: environment
        
        # Все переменные из ConfigMap
        - name: CONFIG_LITERAL
          valueFrom:
            configMapKeyRef:
              name: app-config-literal
              key: APP_NAME
```

**2. Тестируем:**
```bash
kubectl apply -f deployment-with-env.yaml

# Проверяем переменные в Pod
kubectl exec deployment/app-with-config -- env | grep APP
kubectl exec deployment/app-with-config -- env | grep ENVIRONMENT

# Или зайдем в Pod
kubectl exec deployment/app-with-config -it -- sh
echo $APP_NAME
echo $ENVIRONMENT
exit
```

### 🎯 Задание 2.3: Подключение ConfigMap как файлов

**1. Создаем ConfigMap с конфигурацией:**
```yaml
# configmap-files.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config-files
data:
  config.properties: |
    app.name=My Application
    app.version=2.0.0
    server.port=8080
    debug.mode=true
    
  application.yml: |
    app:
      name: "ConfigMap App"
      version: "2.1.0"
    server:
      port: 8080
    logging:
      level: INFO
      
  custom-config.js: |
    const CONFIG = {
        version: '3.0.0',
        environment: 'production',
        api: {
            baseUrl: 'https://api.production.com',
            timeout: 5000
        }
    };
```

**2. Создаем Deployment который монтирует ConfigMap как файлы:**
```yaml
# deployment-with-files.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-files
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-with-files
  template:
    metadata:
      labels:
        app: app-with-files
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: config-volume
          mountPath: /etc/app-config
          readOnly: true
        - name: js-config-volume
          mountPath: /usr/share/nginx/html/config.js
          subPath: custom-config.js
          readOnly: true
      volumes:
      - name: config-volume
        configMap:
          name: app-config-files
      - name: js-config-volume
        configMap:
          name: app-config-files
          items:
          - key: custom-config.js
            path: config.js
```

**3. Тестируем:**
```bash
kubectl apply -f configmap-files.yaml -f deployment-with-files.yaml

# Проверяем файлы в Pod
kubectl exec deployment/app-with-files -- ls -la /etc/app-config/
kubectl exec deployment/app-with-files -- cat /etc/app-config/config.properties
kubectl exec deployment/app-with-files -- cat /usr/share/nginx/html/config.js

# Создаем сервис для проверки в браузере
kubectl expose deployment app-with-files --type=NodePort --port=80 --name=app-files-service
minikube service app-files-service --url
```

### 🎯 Задание 2.4: Обновление ConfigMap

**1. Обновляем ConfigMap:**
```bash
# Способ 1: Редактируем напрямую
kubectl edit configmap app-config-files

# Меняем version на "3.0.0" в custom-config.js
# Или через patch
kubectl patch configmap app-config-files --type='json' -p='[{"op": "replace", "path": "/data/custom-config.js", "value": "const CONFIG = { version: \\\"4.0.0\\\", environment: \\\"production\\\" };"}]'

# Проверяем обновление
kubectl get configmap app-config-files -o yaml
```

**2. Упражнение: Автоматическое обновление**
```bash
# ConfigMap обновился, но что с Pod?
kubectl exec deployment/app-with-files -- cat /usr/share/nginx/html/config.js

# Как принудительно обновить Pod?
kubectl rollout restart deployment/app-with-files

# Проверяем снова
kubectl exec deployment/app-with-files -- cat /usr/share/nginx/html/config.js
```

---

## 🔐 ЧАСТЬ 3: Secrets

### 🎯 Задание 3.1: Создание Secrets

**Теория:**
- Secrets хранят чувствительные данные
- Данные хранятся в base64 encoded виде
- Более безопасны чем ConfigMap, но не полностью зашифрованы

**1. Способ 1: Из literal значений**
```bash
# Создаем secret (данные автоматически кодируются в base64)
kubectl create secret generic app-secrets \
  --from-literal=db-password="super-secret-password-123" \
  --from-literal=api-token="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" \
  --from-literal=admin-password="admin123!"

# Проверяем
kubectl get secret app-secrets
kubectl describe secret app-secrets

# Смотрим данные (они в base64)
kubectl get secret app-secrets -o yaml

# Декодируем для проверки
kubectl get secret app-secrets -o jsonpath='{.data.db-password}' | base64 --decode
echo
```

**2. Способ 2: Из файлов**
```bash
# Создаем файлы с секретами
echo "postgres://user:pass@localhost:5432/mydb" > database.url
echo "secret-jwt-key-here" > jwt.secret
echo "smtp://user:pass@smtp.example.com:587" > email.credentials

# Создаем secret из файлов
kubectl create secret generic app-secrets-files \
  --from-file=./database.url \
  --from-file=./jwt.secret \
  --from-file=./email.credentials

kubectl get secret app-secrets-files -o yaml
```

**3. Способ 3: Из YAML файла**
```yaml
# secret-manual.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets-manual
type: Opaque
data:
  # Данные должны быть в base64!
  database-url: cG9zdGdyZXM6Ly9teC11c2VyOnN1cGVyLXNlY3JldC1wYXNzQGRiLmV4YW1wbGUuY29tOjU0MzIvbXlkYg==
  redis-password: cmVkaXMtc2VjcmV0LXBhc3MxMjM=
  encryption-key: dGhpc2lzYXZlcnlzZWNyZXRrZXk=
```

```bash
# Закодируем данные в base64 для примера
echo -n "postgres://my-user:super-secret-pass@db.example.com:5432/mydb" | base64
echo -n "redis-secret-pass123" | base64
echo -n "thisisaverysecretkey" | base64

kubectl apply -f secret-manual.yaml
kubectl get secret app-secrets-manual
```

### 🎯 Задание 3.2: Использование Secrets как переменных окружения

**1. Создаем Deployment с секретами:**
```yaml
# deployment-with-secrets.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-secrets
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-with-secrets
  template:
    metadata:
      labels:
        app: app-with-secrets
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        env:
        # Секреты как отдельные переменные
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
        - name: API_TOKEN
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: api-token
        
        # Все данные из secret как переменные
        - name: SECRET_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets-manual
              key: redis-password
```

**2. Тестируем:**
```bash
kubectl apply -f deployment-with-secrets.yaml

# Проверяем переменные (значения будут в plain text внутри контейнера)
kubectl exec deployment/app-with-secrets -- env | grep PASSWORD
kubectl exec deployment/app-with-secrets -- env | grep TOKEN

# Важно: внутри Pod переменные уже декодированы!
kubectl exec deployment/app-with-secrets -it -- sh
echo $DATABASE_PASSWORD
echo $API_TOKEN
exit
```

### 🎯 Задание 3.3: Использование Secrets как файлов

**1. Создаем Deployment с секретами как файлами:**
```yaml
# deployment-with-secret-files.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-secret-files
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app-with-secret-files
  template:
    metadata:
      labels:
        app: app-with-secret-files
    spec:
      containers:
      - name: web
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: secret-volume
          mountPath: /etc/secrets
          readOnly: true
        - name: tls-volume
          mountPath: /etc/ssl/private
          readOnly: true
      volumes:
      - name: secret-volume
        secret:
