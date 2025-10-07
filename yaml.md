
---

## **📁 YAML ДЛЯ АВТОДЕПЛОЯ - ПОЛНАЯ РАСШИФРОВКА**

### **1. GITLAB CI/CD - .gitlab-ci.yml**

```yaml
# === СЕКЦИЯ: ОПРЕДЕЛЕНИЕ ПЕРЕМЕННЫХ И ОБРАЗОВ ===
# Используем официальный Docker образ с Node.js
image: node:16-alpine

# Переменные окружения
variables:
  NODE_ENV: production
  DATABASE_URL: postgresql://user:pass@db:5432/app

# Кэширование для ускорения сборок
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/

# === СЕКЦИЯ: СТАДИИ ПАЙПЛАЙНА ===
stages:
  - test          # Тестирование
  - build         # Сборка
  - deploy        # Развертывание

# === СТАДИЯ: ТЕСТИРОВАНИЕ ===
unit_tests:
  stage: test
  script:
    - npm install
    - npm run test:unit
  only:
    - merge_requests  # Запускать только для MR

integration_tests:
  stage: test
  script:
    - npm run test:integration
  dependencies: []  # Не зависеть от предыдущих jobs

# === СТАДИЯ: СБОРКА ===
build_frontend:
  stage: build
  script:
    - npm run build
    - tar -czf frontend.tar.gz dist/
  artifacts:
    paths:
      - frontend.tar.gz
    expire_in: 1 week  # Артефакты храним 1 неделю

build_docker_image:
  stage: build
  image: docker:latest
  services:
    - docker:dind  # Docker-in-Docker для сборки образов
  script:
    - docker build -t myapp:$CI_COMMIT_SHA .
    - docker push myapp:$CI_COMMIT_SHA
  only:
    - main  # Собирать только для main ветки

# === СТАДИЯ: РАЗВЕРТЫВАНИЕ ===
deploy_staging:
  stage: deploy
  image: alpine:latest
  script:
    - apk add --no-cache openssh-client
    - scp frontend.tar.gz user@staging-server:/app/
    - ssh user@staging-server "cd /app && tar -xzf frontend.tar.gz"
  environment:
    name: staging
    url: https://staging.myapp.com
  only:
    - main

deploy_production:
  stage: deploy
  environment:
    name: production
    url: https://myapp.com
  script:
    - curl -X POST https://api.heroku.com/apps/myapp/deploy \
           -H "Authorization: Bearer $HEROKU_API_KEY"
  when: manual  # Ручное подтверждение деплоя
  only:
    - tags  # Только при создании тегов
```

---

## **🐳 DOCKER COMPOSE - docker-compose.yml**

```yaml
# === ВЕРСИЯ ФАЙЛА ===
version: '3.8'

# === СЕРВИСЫ (КОНТЕЙНЕРЫ) ===
services:
  # === ВЕБ-ПРИЛОЖЕНИЕ ===
  web:
    image: nginx:alpine
    build:
      context: ./frontend
      dockerfile: Dockerfile.frontend
    ports:
      - "80:80"      # Проброс портов: хост:контейнер
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro  # Монтирование конфигов
      - static_volume:/app/static
    environment:
      - NGINX_HOST=localhost
      - NGINX_PORT=80
    depends_on:
      - api         # Зависимость от API сервиса
    networks:
      - frontend
      - backend

  # === API СЕРВИС ===
  api:
    image: node:16-alpine
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
      - REDIS_URL=redis://redis:6379
      - NODE_ENV=production
    depends_on:
      db:
        condition: service_healthy  # Ждать готовности БД
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - backend

  # === БАЗА ДАННЫХ ===
  db:
    image: postgres:13
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d app"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - backend

  # === REDIS ===
  redis:
    image: redis:6-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend

# === VOLUMES (ХРАНИЛИЩА ДАННЫХ) ===
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  static_volume:
    driver: local

# === NETWORKS (СЕТИ) ===
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

---

## **☸️ KUBERNETES DEPLOYMENT - deployment.yml**

```yaml
# === DEPLOYMENT (УПРАВЛЕНИЕ POD'ами) ===
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
  labels:
    app: web-app
    version: v1.2.3
spec:
  replicas: 3  # Количество копий приложения
  selector:
    matchLabels:
      app: web-app
  strategy:
    type: RollingUpdate  # Стратегия обновления
    rollingUpdate:
      maxSurge: 1        # Макс. дополнительных pod'ов при обновлении
      maxUnavailable: 0  # Минимум доступных pod'ов
  template:
    metadata:
      labels:
        app: web-app
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.21-alpine
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          protocol: TCP
        env:
        - name: NGINX_ENV
          value: production
        resources:
          requests:  # Минимальные ресурсы
            memory: "128Mi"
            cpu: "100m"
          limits:    # Максимальные ресурсы
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:   # Проверка живости
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:  # Проверка готовности
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: config-volume
        configMap:
          name: nginx-config
---
# === SERVICE (СЕТЕВОЙ ДОСТУП) ===
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: production
spec:
  selector:
    app: web-app
  ports:
  - name: http
    port: 80           # Порт сервиса
    targetPort: 80     # Порт контейнера
    protocol: TCP
  type: LoadBalancer   # Тип сервиса
---
# === CONFIGMAP (КОНФИГУРАЦИИ) ===
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: production
data:
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
---
# === HORIZONTAL POD AUTOSCALER (АВТОМАСШТАБИРОВАНИЕ) ===
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: web-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

## **🚀 GITHUB ACTIONS - .github/workflows/deploy.yml**

```yaml
# === НАЗВАНИЕ ВОРКФЛОУ ===
name: Deploy to Production

# === ТРИГГЕРЫ ЗАПУСКА ===
on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]  # Запуск при тегах v1.0.0 и т.д.
  pull_request:
    branches: [ main ]

# === ПЕРЕМЕННЫЕ ===
env:
  NODE_VERSION: '16'
  DOCKER_IMAGE: ghcr.io/${{ github.repository }}

# === ДЖОБЫ ===
jobs:
  # === ТЕСТИРОВАНИЕ ===
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: ${{ env.NODE_VERSION }}
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Run unit tests
      run: npm test

    - name: Run security audit
      run: npm audit

  # === СБОРКА И ПУШ ДОКЕР ОБРАЗА ===
  build-and-push:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: test  # Зависит от успешного тестирования
    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Login to GitHub Container Registry
      uses: docker/login-action@v2
      with:
        registry: ghcr.io
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Build Docker image
      run: |
        docker build -t ${{ env.DOCKER_IMAGE }}:${{ github.sha }} .
        docker build -t ${{ env.DOCKER_IMAGE }}:latest .

    - name: Push Docker images
      run: |
        docker push ${{ env.DOCKER_IMAGE }}:${{ github.sha }}
        docker push ${{ env.DOCKER_IMAGE }}:latest

  # === ДЕПЛОЙ НА PRODUCTION ===
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: build-and-push
    environment: production
    steps:
    - name: Deploy to Kubernetes
      uses: azure/k8s-deploy@v1
      with:
        namespace: production
        manifests: |
          k8s/deployment.yml
          k8s/service.yml
        images: |
          ${{ env.DOCKER_IMAGE }}:${{ github.sha }}
        kubectl-version: 'latest'

    - name: Verify deployment
      run: |
        kubectl rollout status deployment/web-app -n production
        kubectl get pods -n production

    - name: Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        text: 🚀 Production deployment completed!
      env:
        SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## **🔑 РАСШИФРОВКА КЛЮЧЕВЫХ СЕКЦИЙ YAML**

### **Общая структура YAML:**
```yaml
# Комментарии начинаются с #
key: value                    # Строка
number: 42                    # Число
boolean: true                 # Булево значение
list:                         # Список
  - item1
  - item2
dictionary:                   # Словарь
  key1: value1
  key2: value2
multiline: |                  # Многострочный текст
  Это
  многострочный
  текст
```

### **Ключевые концепции автодеплоя:**

1. **CI/CD Pipeline** — автоматизированный процесс: тестирование → сборка → деплой
2. **Docker/Containers** — изоляция приложения и его зависимостей
3. **Orchestration** — управление множеством контейнеров (Kubernetes)
4. **Infrastructure as Code** — описание инфраструктуры в коде
5. **Rolling Updates** — бесшовное обновление без downtime

### **Переменные и секреты:**
- **Environment Variables** — настройки окружения
- **Secrets** — чувствительные данные (пароли, токены)
- **ConfigMaps** — конфигурационные файлы
- **Artifacts** — результаты сборки

Каждый YAML файл описывает желаемое состояние системы, а инструменты автоматизации обеспечивают соответствие этому состоянию! 🚀