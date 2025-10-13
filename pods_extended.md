# Полная структура проекта Kubernetes для обучения

## Что нужно добавить к предыдущему примеру:

```
kubernetes-learning/
├── 00-setup/                    # Настройка окружения
│   ├── install.sh
│   └── verify-setup.sh
├── 01-pods/                     # Работа с Pod'ами
│   ├── simple-pod.yaml
│   ├── multiple-pods.yaml
│   ├── pod-with-env.yaml
│   ├── pod-with-resources.yaml
│   └── commands.txt
├── 02-deployments/              # Работа с Deployments
│   ├── simple-deployment.yaml
│   ├── deployment-with-probes.yaml
│   ├── deployment-with-update.yaml
│   └── commands.txt
├── 03-services/                 # Работа с Services
│   ├── clusterip-service.yaml
│   ├── nodeport-service.yaml
│   ├── loadbalancer-service.yaml
│   └── commands.txt
├── 04-configmaps-secrets/       # Конфигурации
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── pod-with-configmap.yaml
│   └── commands.txt
├── 05-volumes/                  # Тома и хранилище
│   ├── pod-with-volume.yaml
│   ├── configmap-volume.yaml
│   └── commands.txt
├── 06-practice/                 # Практические задания
│   ├── exercise-1.yaml
│   ├── exercise-2.yaml
│   ├── exercise-3.yaml
│   └── solutions/
├── 07-complete-app/             # Полное приложение
│   ├── frontend-deployment.yaml
│   ├── backend-deployment.yaml
│   ├── database-deployment.yaml
│   ├── services.yaml
│   └── configmaps.yaml
├── scripts/                     # Вспомогательные скрипты
│   ├── cleanup.sh
│   ├── status.sh
│   └── port-forward.sh
└── README.md                    # Инструкция
```

## Содержимое каждого файла:

### 1. Настройка окружения (`00-setup/`)

**`install.sh`**:
```bash
#!/bin/bash
echo "Установка Kubernetes learning environment..."

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Установка kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Установка Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

echo "Установка завершена. Перезапустите терминал или выполните: newgrp docker"
```

**`verify-setup.sh`**:
```bash
#!/bin/bash
echo "Проверка установки..."

# Проверка Docker
docker --version
docker ps

# Проверка kubectl
kubectl version --client

# Проверка Minikube
minikube version

# Запуск кластера
echo "Запуск Minikube кластера..."
minikube start --driver=docker

# Проверка кластера
kubectl cluster-info
kubectl get nodes

echo "Проверка завершена!"
```

### 2. Работа с Pod'ами (`01-pods/`)

**`simple-pod.yaml`** (уже есть):
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-first-pod
  labels:
    app: hello-world
    environment: learning
spec:
  containers:
  - name: nginx-container
    image: nginx:alpine
    ports:
    - containerPort: 80
```

**`pod-with-env.yaml`**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-environment
spec:
  containers:
  - name: app-container
    image: busybox:latest
    command: ['sh', '-c', 'echo "Hello $NAME! Database: $DB_URL" && sleep 3600']
    env:
    - name: NAME
      value: "Kubernetes Student"
    - name: DB_URL
      value: "postgresql://localhost:5432/mydb"
    - name: LOG_LEVEL
      value: "DEBUG"
```

**`pod-with-resources.yaml`**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-resources
spec:
  containers:
  - name: limited-container
    image: nginx:alpine
    resources:
      requests:
        memory: "64Mi"
        cpu: "50m"
      limits:
        memory: "128Mi"
        cpu: "100m"
    ports:
    - containerPort: 80
```

**`commands.txt`**:
```bash
# Создание Pod'ов
kubectl apply -f simple-pod.yaml
kubectl apply -f pod-with-env.yaml
kubectl apply -f pod-with-resources.yaml

# Просмотр
kubectl get pods
kubectl get pods -o wide

# Детальная информация
kubectl describe pod my-first-pod

# Логи
kubectl logs my-first-pod
kubectl logs pod-with-environment

# Запуск команд внутри Pod'а
kubectl exec -it pod-with-environment -- /bin/sh
# env | grep NAME
# exit

# Удаление
kubectl delete -f simple-pod.yaml
kubectl delete pod pod-with-environment
```

### 3. Deployments (`02-deployments/`)

**`simple-deployment.yaml`**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: simple-app
  template:
    metadata:
      labels:
        app: simple-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
```

**`deployment-with-probes.yaml`**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-with-healthchecks
spec:
  replicas: 3
  selector:
    matchLabels:
      app: healthy-app
  template:
    metadata:
      labels:
        app: healthy-app
    spec:
      containers:
      - name: web-server
        image: nginx:alpine
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

**`deployment-with-update.yaml`**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: updatable-deployment
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: updatable-app
  template:
    metadata:
      labels:
        app: updatable-app
    spec:
      containers:
      - name: app
        image: nginx:1.18-alpine
        ports:
        - containerPort: 80
```

**`commands.txt`**:
```bash
# Создание Deployment'ов
kubectl apply -f simple-deployment.yaml
kubectl apply -f deployment-with-probes.yaml

# Просмотр
kubectl get deployments
kubectl get pods -l app=simple-app

# Масштабирование
kubectl scale deployment simple-deployment --replicas=5
kubectl get pods

# Обновление образа
kubectl set image deployment/updatable-deployment app=nginx:1.19-alpine

# История обновлений
kubectl rollout history deployment/updatable-deployment

# Откат
kubectl rollout undo deployment/updatable-deployment

# Статус обновления
kubectl rollout status deployment/updatable-deployment
```

### 4. Services (`03-services/`)

**`clusterip-service.yaml`**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: clusterip-service
spec:
  type: ClusterIP
  selector:
    app: simple-app
  ports:
  - port: 80
    targetPort: 80
```

**`nodeport-service.yaml`**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nodeport-service
spec:
  type: NodePort
  selector:
    app: simple-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30007
```

**`loadbalancer-service.yaml`**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: loadbalancer-service
spec:
  type: LoadBalancer
  selector:
    app: simple-app
  ports:
  - port: 80
    targetPort: 80
```

**`commands.txt`**:
```bash
# Создание сервисов
kubectl apply -f clusterip-service.yaml

# Просмотр сервисов
kubectl get services
kubectl describe service clusterip-service

# Доступ к сервису
minikube service nodeport-service
minikube service loadbalancer-service

# Тестирование изнутри кластера
kubectl run test-pod --image=busybox -it --rm -- /bin/sh
# wget -qO- http://clusterip-service:80
# exit
```

### 5. ConfigMaps и Secrets (`04-configmaps-secrets/`)

**`configmap.yaml`**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.properties: |
    database.url=jdbc:postgresql://localhost:5432/mydb
    cache.enabled=true
    log.level=DEBUG
  config.yaml: |
    server:
      port: 8080
      host: 0.0.0.0
    features:
      newUI: true
      analytics: false
```

**`secret.yaml`**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: Opaque
data:
  username: YWRtaW4=  # admin
  password: cGFzc3dvcmQ=  # password
  api-key: bXktc2VjcmV0LWFwaS1rZXk=
```

**`pod-with-configmap.yaml`**:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-config
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ['sh', '-c', 'echo "Config: $CONFIG_VALUE, Secret: $SECRET_VALUE" && sleep 3600']
    env:
    - name: CONFIG_VALUE
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: log.level
    - name: SECRET_VALUE
      valueFrom:
        secretKeyRef:
          name: app-secret
          key: username
    envFrom:
    - configMapRef:
        name: app-config
    - secretRef:
        name: app-secret
```

### 6. Практические задания (`06-practice/`)

**`exercise-1.yaml`**:
```yaml
# Задание 1: Создай Pod с nginx который:
# - Имеет метки: app=web, tier=frontend
# - Использует образ nginx:1.19
# - Открывает порт 80
# - Имеет переменную окружения ENV=production
# - Запрашивает 100m CPU и 128Mi памяти
# API Version: v1
# Kind: Pod
# Name: exercise-web-pod
```

**`exercise-2.yaml`**:
```yaml
# Задание 2: Создай Deployment который:
# - Управляет 3 репликами
# - Использует образ nginx:alpine
# - Имеет liveness и readiness пробы
# - Стратегия обновления: RollingUpdate с maxUnavailable=0
# - Pod'ы должны иметь метку app=exercise-app
```

### 7. Вспомогательные скрипты (`scripts/`)

**`cleanup.sh`**:
```bash
#!/bin/bash
echo "Очистка всех ресурсов..."

kubectl delete --all pods
kubectl delete --all deployments
kubectl delete --all services
kubectl delete --all configmaps
kubectl delete --all secrets

echo "Очистка завершена"
```

**`status.sh`**:
```bash
#!/bin/bash
echo "=== Статус кластера ==="
kubectl cluster-info

echo "=== Nodes ==="
kubectl get nodes

echo "=== Все ресурсы ==="
kubectl get all

echo "=== ConfigMaps ==="
kubectl get configmaps

echo "=== Secrets ==="
kubectl get secrets
```

**`port-forward.sh`**:
```bash
#!/bin/bash
SERVICE_NAME=${1:-clusterip-service}
PORT=${2:-8080}

echo "Port forwarding для сервиса $SERVICE_NAME на порт $PORT"
kubectl port-forward service/$SERVICE_NAME $PORT:80
```

### 8. README.md

```markdown
# Kubernetes Learning Project

Полный проект для изучения Kubernetes на Ubuntu 24.04.

## Структура проекта

```
kubernetes-learning/
├── 00-setup/          # Настройка окружения
├── 01-pods/           # Основы Pod'ов
├── 02-deployments/    # Управление приложениями
├── 03-services/       # Сетевой доступ
├── 04-configmaps/     # Конфигурации
├── 05-volumes/        # Хранилище
├── 06-practice/       # Упражнения
├── 07-complete-app/   # Полное приложение
└── scripts/           # Вспомогательные скрипты
```

## Начало работы

1. Настройка окружения:
```bash
cd 00-setup
chmod +x install.sh verify-setup.sh
./install.sh
./verify-setup.sh
```

2. Изучение по порядку:
- Начни с `01-pods/`
- Переходи к следующей папке после освоения текущей

## Полезные команды

```bash
# Просмотр ресурсов
./scripts/status.sh

# Очистка
./scripts/cleanup.sh

# Port forwarding
./scripts/port-forward.sh
```

## Рекомендуемый порядок изучения

1. Pod'ы - базовые единицы развертывания
2. Deployments - управление репликами и обновлениями
3. Services - сетевое взаимодействие
4. ConfigMaps и Secrets - управление конфигурацией
5. Volumes - работа с хранилищем
6. Practice - закрепление знаний
```

## Как использовать этот проект:

1. **Скачай или создай эту структуру** на своей Ubuntu 24.04
2. **Выполни настройку**:
   ```bash
   cd kubernetes-learning/00-setup
   chmod +x *.sh
   ./install.sh
   # Перезапусти терминал
   ./verify-setup.sh
   ```
3. **Изучай по порядку** папки с 01 по 06
4. **Выполняй упражнения** в папке `06-practice/`
5. **Используй скрипты** для упрощения работы

Этот проект даст тебе полное понимание всех основных концепций Kubernetes!