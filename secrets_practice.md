
# 🔐 Инструкция по получению паролей и данных для Kubernetes практики

## 1. Пароли доступа к виртуальной машине

### Что нужно:
- **Логин и пароль пользователя** для входа в Ubuntu 24.04
- **Права sudo** для установки программ

### Как получить:

**Если вы создавали VM сами:**
```bash
# Проверить текущего пользователя
whoami

# Проверить права sudo
sudo -l

# Если нет прав sudo, нужно добавить пользователя (из-под root):
sudo su -
usermod -aG sudo ваше_имя_пользователя
exit
```

**Если VM предоставлена преподавателем/работодателем:**
- Запросите логин/пароль у администратора
- Или используйте SSH ключи, если предоставлены

**Проверка доступа:**
```bash
# Проверить что можете выполнять команды с sudo
sudo echo "Успех! Sudo работает"

# Проверить пароль (если запрашивается)
# Введите ваш пароль пользователя при запросе
```

## 2. Данные для установки Kubernetes (Minikube)

### Требуемые данные:
- **URL для скачивания Minikube**
- **URL для скачивания kubectl**
- **Доступ к интернету**

### Как получить:

```bash
# 1. Проверить интернет
ping -c 3 google.com
# Если не работает, проверьте сетевые настройки VM

# 2. Получить актуальные URL (выполнять на рабочей машине с интернетом)
# Для Minikube:
echo "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"

# Для kubectl:
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
echo "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

# 3. Если интернет ограничен, скачайте файлы заранее на другой машине
# и перенесите на VM через SCP или USB
```

**Альтернативные источники если основные URL не работают:**
```bash
# GitHub releases Minikube
echo "https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64"

# Альтернативный mirror для kubectl
echo "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
```

## 3. Пароли и данные для Docker образов

### Что нужно:
- **Имена Docker образов** для практики
- **Доступ к Docker Hub** или альтернативному registry

### Используемые образы и их аналоги:

```bash
# Основные образы (должны быть доступны бесплатно):
NGINX="nginx:1.25-alpine"           # или nginx:latest
REDIS="redis:7-alpine"              # или redis:latest
ALPINE="alpine:3.18"                # базовый образ
BUSYBOX="busybox:1.36"              # альтернатива alpine

# Специальные образы для тестов:
# Если эти недоступны, используем альтернативы
```

**Если образы недоступны, создаем локальные альтернативы:**

```bash
# Создаем простой веб-сервер на Python вместо whoami
cat > simple-webserver.py << 'EOF'
from http.server import HTTPServer, BaseHTTPRequestHandler

class SimpleHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/plain')
        self.end_headers()
        response = f"Hello from {self.server.server_address}\nPath: {self.path}\n"
        self.wfile.write(response.encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), SimpleHandler)
    server.serve_forever()
EOF

# Создаем Dockerfile для нашего тестового образа
cat > Dockerfile << 'EOF'
FROM python:3.9-alpine
COPY simple-webserver.py /app/
WORKDIR /app
EXPOSE 8080
CMD ["python", "simple-webserver.py"]
EOF

# Собираем образ
docker build -t my-test-app:latest .
```

## 4. Пароли для Secrets практики

### Тестовые пароли которые мы будем использовать:

**1. База данных:**
```bash
# Эти пароли создаем САМИ - они тестовые!
DB_PASSWORD="MySuperSecretDB123!"
DB_ROOT_PASSWORD="RootAdminPass456!"
POSTGRES_PASSWORD="pg_secret_789"

# Альтернативно, генерируем случайные пароли
openssl rand -base64 16
# Результат: 7BhcGv8lLk3pXq2WZ5RdA==
```

**2. API ключи и токены:**
```bash
# JWT секрет (генерируем сами)
JWT_SECRET="jwt_super_secret_key_2024_k8s_practice"

# API токен
API_TOKEN="kp_12345_abcde_67890_fghij"

# Если нужны более реальные данные:
echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c" | base64
```

**3. SSH ключи (если нужны):**
```bash
# Генерируем тестовый SSH ключ
ssh-keygen -t rsa -b 2048 -f test_key -N "" -q

# Публичный ключ
cat test_key.pub

# Приватный ключ (для secret)
cat test_key
```

## 5. Конфигурационные данные для ConfigMaps

### Данные которые создаем САМИ:

**1. Настройки приложения:**
```bash
# Создаем файл application.properties
cat > application.properties << 'EOF'
# Application Settings
app.name=Kubernetes Practice Application
app.version=1.0.0
app.environment=production

# Server Settings
server.port=8080
server.host=0.0.0.0

# Database Settings
db.host=postgresql-service
db.port=5432
db.name=k8s_practice

# Feature Flags
features.authentication=true
features.caching=false
features.analytics=true

# Logging
logging.level=INFO
logging.file=/var/log/app.log
EOF
```

**2. Конфигурация веб-сервера:**
```bash
# Создаем nginx.conf
cat > nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html index.htm;

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Config check endpoint
    location /config {
        return 200 "config_loaded_successfully\n";
    }

    # Main application
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}
EOF
```

**3. JSON конфигурация:**
```bash
# Создаем config.json
cat > config.json << 'EOF'
{
  "application": {
    "name": "K8s Practice App",
    "version": "1.0.0",
    "environment": "production"
  },
  "database": {
    "host": "localhost",
    "port": 5432,
    "name": "k8s_practice_db"
  },
  "features": {
    "authentication": true,
    "caching": false,
    "monitoring": true
  },
  "logging": {
    "level": "INFO",
    "file": "/var/log/app.log"
  }
}
EOF
```

## 6. Полный скрипт генерации всех данных

**Создаем `generate-all-data.sh`:**
```bash
#!/bin/bash

echo "🔐 Генерация всех тестовых данных для Kubernetes практики..."
mkdir -p ~/k8s-practice
cd ~/k8s-practice

echo "📝 Создаем ConfigMap данные..."
# Application configs
cat > app-config.properties << 'EOF'
app.name=Kubernetes Training App
app.version=2.1.0
environment=staging
server.port=8080
db.host=postgres-service
db.port=5432
log.level=DEBUG
EOF

cat > frontend-config.js << 'EOF'
const CONFIG = {
    appName: "K8s Frontend",
    version: "1.5.0",
    api: {
        baseUrl: "https://api.staging.com",
        timeout: 5000
    },
    features: {
        darkMode: true,
        analytics: true
    }
};
EOF

echo "🔐 Генерируем Secret данные..."
# Generate random passwords
DB_PASSWORD=$(openssl rand -base64 16 | tr -d '\n')
API_KEY=$(openssl rand -hex 20)
JWT_SECRET=$(openssl rand -base64 32 | tr -d '\n')

echo "Сгенерированные секреты:"
echo "DB_PASSWORD: $DB_PASSWORD"
echo "API_KEY: $API_KEY" 
echo "JWT_SECRET: $JWT_SECRET"

# Save secrets to files (for practice)
echo "$DB_PASSWORD" > db-password.txt
echo "$API_KEY" > api-key.txt
echo "$JWT_SECRET" > jwt-secret.txt

# Create secret configuration files
echo "postgres://admin:${DB_PASSWORD}@db-host:5432/production" > database-url.txt
echo "Authorization: Bearer ${API_KEY}" > api-header.txt

echo "📊 Создаем тестовые данные приложения..."
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>K8s Practice</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .card { background: #f8f9fa; padding: 20px; margin: 10px 0; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎯 Kubernetes Практическое Приложение</h1>
        
        <div class="card">
            <h2>Информация о приложении</h2>
            <div id="app-info"></div>
        </div>
        
        <div class="card">
            <h2>Конфигурация</h2>
            <div id="config-info"></div>
        </div>
    </div>

    <script>
        // Эти данные будут заменены через ConfigMap
        const APP_INFO = {
            name: "K8s Practice App",
            version: "1.0.0",
            environment: "development"
        };

        const CONFIG = {
            apiUrl: "http://localhost:8080",
            features: ["auth", "cache", "monitoring"]
        };

        document.getElementById('app-info').innerHTML = \`
            <p><strong>Имя:</strong> \${APP_INFO.name}</p>
            <p><strong>Версия:</strong> \${APP_INFO.version}</p>
            <p><strong>Окружение:</strong> \${APP_INFO.environment}</p>
        \`;

        document.getElementById('config-info').innerHTML = \`
            <p><strong>API URL:</strong> \${CONFIG.apiUrl}</p>
            <p><strong>Функции:</strong> \${CONFIG.features.join(', ')}</p>
        \`;
    </script>
</body>
</html>
EOF

echo "✅ Все данные сгенерированы в ~/k8s-practice/"
echo ""
echo "📋 Созданные файлы:"
ls -la
echo ""
echo "🔐 Сгенерированные секреты сохранены в файлах:"
echo "   - db-password.txt"
echo "   - api-key.txt" 
echo "   - jwt-secret.txt"
echo ""
echo "⚠️  Важно: Эти секреты только для учебных целей!"
```

## 7. Инструкция для случаев без интернета

### Если нет доступа к Docker Hub:

**Вариант 1: Используем образы из Minikube**
```bash
# Minikube имеет встроенные образы
minikube ssh docker images

# Используем то что есть
# Вместо nginx:1.25-alpine используем встроенные образы
```

**Вариант 2: Собираем образы локально**
```bash
# Создаем простейший веб-сервер
cat > Dockerfile-simple << 'EOF'
FROM alpine:3.18
RUN apk add --no-cache nginx
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

docker build -f Dockerfile-simple -t local-web-app .
```

## 8. Получение данных от администратора/преподавателя

### Что запросить если данные не генерируются самостоятельно:

```bash
# 1. Учетные данные для VM
#    - IP адрес/хостнейм
#    - Логин
#    - Пароль или SSH ключ

# 2. Доступ к образам Docker
#    - Internal registry URL (если есть)
#    - Логин/пароль для registry

# 3. Сетевые настройки
#    - DNS серверы
#    - Прокси настройки (если нужны)
#    - Разрешенные порты

# 4. Учетные данные для cloud провайдера (если применимо)
#    - Access keys
#    - Secret keys
#    - Region/zone
```


```

## 9. Быстрая проверка готовности

**Создаем `quick-check.sh`:**
```bash
#!/bin/bash

echo "🔍 Проверка доступности данных..."

# Проверка базовых утилит
echo "1. Проверка системных утилит..."
for cmd in curl wget sudo; do
    if command -v $cmd &> /dev/null; then
        echo "✅ $cmd доступен"
    else
        echo "❌ $cmd отсутствует"
    fi
done

# Проверка данных
echo "2. Проверка тестовых данных..."
cd ~/k8s-practice
if [ -d ~/k8s-practice ]; then
    echo "✅ Директория практики создана"
    
    # Проверка ConfigMap данных
    for file in app-config.properties frontend-config.js index.html; do
        if [ -f "$file" ]; then
            echo "✅ $file существует"
        else
            echo "❌ $file отсутствует"
        fi
    done
    
    # Проверка Secret данных
    for file in db-password.txt api-key.txt; do
        if [ -f "$file" ]; then
            echo "✅ $file существует"
        else
            echo "❌ $file отсутствует"
        fi
    done
else
    echo "❌ Директория практики не создана"
fi

# Проверка Minikube
echo "3. Проверка Kubernetes..."
if command -v minikube &> /dev/null; then
    minikube status &> /dev/null && echo "✅ Minikube запущен" || echo "❌ Minikube не запущен"
else
    echo "❌ Minikube не установлен"
fi

if command -v kubectl &> /dev/null; then
    kubectl version --short &> /dev/null && echo "✅ kubectl работает" || echo "❌ kubectl не работает"
else
    echo "❌ kubectl не установлен"
fi

echo ""
echo "🎯 Готовность к практике:"
echo "Если все проверки пройдены ✅ - можно начинать!"
echo "Если есть ❌ - выполните подготовительные шаги"
```

## Запуск всей подготовки одной командой

```bash
# Делаем скрипты исполняемыми
chmod +x generate-all-data.sh quick-check.sh

# Генерируем все данные
./generate-all-data.sh

# Проверяем готовность
./quick-check.sh
```


**Краткий чек-лист:**
- [ ] Созданы тестовые ConfigMap данные
- [ ] Сгенерированы Secret данные  
- [ ] Подготовлены HTML/конфигурационные файлы
- [ ] Проверен доступ к Minikube и kubectl
- [ ] Создана рабочая директория с всеми файлами


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
          secretName: app-secrets-files
      - name: tls-volume
        secret:
          secretName: app-secrets-manual
          items:
          - key: encryption-key
            path: app.key
            mode: 0400
```

**2. Тестируем:**
```bash
kubectl apply -f deployment-with-secret-files.yaml

# Проверяем файлы
kubectl exec deployment/app-with-secret-files -- ls -la /etc/secrets/
kubectl exec deployment/app-with-secret-files -- cat /etc/secrets/database.url
kubectl exec deployment/app-with-secret-files -- ls -la /etc/ssl/private/

# Проверяем права доступа
kubectl exec deployment/app-with-secret-files -- ls -la /etc/ssl/private/app.key
```

### 🎯 Задание 3.4: Практический пример - приложение с конфигурацией и секретами

**1. Создаем полную конфигурацию:**
```yaml
# full-app-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: full-app-config
data:
  application.properties: |
    app.name=Full Kubernetes App
    app.version=1.0.0
    server.port=8080
    logging.level=INFO
    features.auth.enabled=true
    features.cache.enabled=false
  nginx-config.conf: |
    server {
        listen 8080;
        server_name localhost;
        root /usr/share/nginx/html;
        
        location /config {
            return 200 "Config loaded successfully\n";
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
        }
    }
---
apiVersion: v1
kind: Secret
metadata:
  name: full-app-secrets
type: Opaque
data:
  # echo -n "real-database-password" | base64
  database.password: cmVhbC1kYXRhYmFzZS1wYXNzd29yZA==
  # echo -n "jwt-secret-key-2024" | base64
  jwt.secret: amV0LXNlY3JldC1rZXktMjAyNA==
  # echo -n "smtp://user:pass@smtp.example.com" | base64
  email.url: c210cDovL3VzZXI6cGFzc0BzbXRwLmV4YW1wbGUuY29t
```

**2. Создаем Deployment который использует всё:**
```yaml
# full-app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: full-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: full-app
  template:
    metadata:
      labels:
        app: full-app
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        ports:
        - containerPort: 8080
        env:
        # Переменные из ConfigMap
        - name: APP_NAME
          valueFrom:
            configMapKeyRef:
              name: full-app-config
              key: app.name
        # Переменные из Secret
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: full-app-secrets
              key: database.password
        volumeMounts:
        - name: config-volume
          mountPath: /etc/app-config
        - name: secret-volume
          mountPath: /etc/app-secrets
          readOnly: true
        - name: nginx-config-volume
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx-config.conf
        command: ["/bin/sh"]
        args: 
        - -c
        - |
          echo "Application: $APP_NAME" > /usr/share/nginx/html/index.html
          echo "Database password: $DB_PASSWORD" >> /usr/share/nginx/html/index.html
          echo "Config files:" >> /usr/share/nginx/html/index.html
          ls -la /etc/app-config/ >> /usr/share/nginx/html/index.html
          echo "Secret files:" >> /usr/share/nginx/html/index.html
          ls -la /etc/app-secrets/ >> /usr/share/nginx/html/index.html
          nginx -g 'daemon off;'
      volumes:
      - name: config-volume
        configMap:
          name: full-app-config
      - name: secret-volume
        secret:
          secretName: full-app-secrets
      - name: nginx-config-volume
        configMap:
          name: full-app-config
          items:
          - key: nginx-config.conf
            path: default.conf
```

**3. Создаем сервис для доступа:**
```yaml
# full-app-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: full-app-service
spec:
  type: NodePort
  selector:
    app: full-app
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30088
```

**4. Тестируем полное приложение:**
```bash
kubectl apply -f full-app-configmap.yaml -f full-app-deployment.yaml -f full-app-service.yaml

# Ждем запуска
kubectl get pods -l app=full-app

# Проверяем сервис
kubectl get service full-app-service

# Тестируем приложение
curl http://$(minikube ip):30088

# Смотрим логи
kubectl logs deployment/full-app -f
```

---

## 🧪 ЧЕК-ЛИСТ ПРОВЕРКИ ЗНАНИЙ

### Проверьте себя:

**✅ Сервисы:**
- [ ] Могу создать ClusterIP сервис
- [ ] Могу создать NodePort сервис  
- [ ] Понимаю разницу между типами сервисов
- [ ] Умею тестировать доступность сервисов

**✅ ConfigMaps:**
- [ ] Могу создать ConfigMap из файлов, literals и YAML
- [ ] Умею подключать ConfigMap как переменные окружения
- [ ] Умею монтировать ConfigMap как файлы
- [ ] Понимаю как обновлять ConfigMap

**✅ Secrets:**
- [ ] Могу создать Secret разными способами
- [ ] Понимаю что данные в Secrets хранятся в base64
- [ ] Умею использовать Secrets как переменные и файлы
- [ ] Понимаю ограничения безопасности Secrets

### 🎯 Финальное упражнение:

**Создайте полное приложение:**
```bash
# 1. Создайте ConfigMap с настройками приложения
# 2. Создайте Secret с паролями и ключами
# 3. Разверните Deployment который использует оба
# 4. Создайте ClusterIP сервис для внутреннего доступа
# 5. Создайте NodePort сервис для внешнего доступа
# 6. Протестируйте работу приложения
```

### 🧹 Очистка:
```bash
# Удаляем все созданные ресурсы
kubectl delete all --all
kubectl delete configmap --all
kubectl delete secret --all

# Останавливаем Minikube
minikube stop
```

---

## 💡 ПОЛЕЗНЫЕ КОМАНДЫ ДЛЯ РАБОТЫ

```bash
# Просмотр ресурсов
kubectl get configmaps,secrets,services,pods

# Детальная информация
kubectl describe configmap <name>
kubectl describe secret <name> 
kubectl describe service <name>

# Проверка внутри Pod
kubectl exec <pod> -- env
kubectl exec <pod> -- ls -la /path/to/mount
kubectl exec <pod> -- cat /path/to/file

# Отладка сервисов
kubectl get endpoints <service>
kubectl logs <pod>
```


1. **Secrets не полностью безопасны** - они только base64 encoded
2. **ConfigMap обновляется не мгновенно** - может потребоваться перезапуск Pod
3. **NodePort порты** должны быть в диапазоне 30000-32767
4. **Всегда проверяйте** что селекторы сервисов совпадают с метками Pod
5. **Используйте describe** для диагностики проблем

