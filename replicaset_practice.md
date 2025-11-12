
# 🚀 Практическое руководство по Kubernetes: Ресурсы, ReplicaSet и Deployment

## 📋 Предварительные требования

### 1. Установка Minikube на Ubuntu 24.04 - пропустите этот шаг, если все уже установлено

```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем зависимости
sudo apt install -y curl wget apt-transport-https

# Скачиваем и устанавливаем Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Устанавливаем kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Запускаем Minikube с 4GB RAM
minikube start --memory=4096 --cpus=2

# Проверяем установку
kubectl get nodes
minikube status
```

### 2. Проверка окружения

```bash
# Создаем рабочую директорию
mkdir ~/k8s-practice && cd ~/k8s-practice

# Проверяем версии
kubectl version --short
minikube version
```

---

## 📚 ЧАСТЬ 1: Управление ресурсами Pod

### 🎯 Задание 1.1: Создание Pod с ограничениями ресурсов

#### Теория:
- **requests**: гарантированные ресурсы для Pod
- **limits**: максимальные ресурсы для Pod
- **CPU**: 1000m = 1 ядро, 500m = 0.5 ядра
- **Memory**: 1Gi = 1024Mi, 512Mi = 512 мегабайт

#### Практика:

**1. Создаем файл `nginx-resources.yaml`:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-limited
  labels:
    app: nginx
    environment: test
spec:
  containers:
  - name: nginx-container
    image: nginx:1.25
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "500m"
```

**2. Применяем конфигурацию:**
```bash
kubectl apply -f nginx-resources.yaml
```

**3. Проверяем ресурсы:**
```bash
kubectl get pod nginx-limited
kubectl describe pod nginx-limited
```

**4. Упражнение: Измените ограничения**
```bash
# Создайте новый файл nginx-resources-v2.yaml с такими ресурсами:
# requests: memory: 256Mi, cpu: 200m
# limits: memory: 512Mi, cpu: 800m

# Примените и проверьте
kubectl apply -f nginx-resources-v2.yaml
```

### 🎯 Задание 1.2: Тестирование ограничений памяти

**1. Создаем Pod который превысит лимиты:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
spec:
  containers:
  - name: memory-hog-container
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "300M", "--vm-hang", "1"]
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
      limits:
        memory: "200Mi"  # Меньше чем использует контейнер!
        cpu: "500m"
```

**2. Наблюдаем за поведением:**
```bash
kubectl apply -f memory-hog.yaml
kubectl get pod memory-hog -w  # Наблюдаем в реальном времени

# В другом терминале смотрим события
kubectl get events --sort-by='.lastTimestamp'
```

**3. Упражнение: Анализ**
```bash
# Что произошло с Pod? Почему?
kubectl describe pod memory-hog
kubectl logs memory-hog
```

---

## 🏷️ ЧАСТЬ 2: Метки (Labels) и селекторы (Selectors)

### 🎯 Задание 2.1: Создание Pod с метками

**1. Создаем несколько Pod с разными метками:**
```yaml
# frontend-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-app
  labels:
    app: frontend
    tier: web
    environment: production
    version: "1.0"
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
```

```yaml
# backend-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend-service
  labels:
    app: backend
    tier: api
    environment: production
    version: "1.0"
spec:
  containers:
  - name: redis
    image: redis:7-alpine
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
```

```yaml
# database-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: database
  labels:
    app: database
    tier: db
    environment: production
    version: "2.1"
spec:
  containers:
  - name: postgres
    image: postgres:15-alpine
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
```

**2. Применяем все Pod:**
```bash
kubectl apply -f frontend-pod.yaml -f backend-pod.yaml -f database-pod.yaml
```

### 🎯 Задание 2.2: Работа с селекторами

**1. Поиск Pod по меткам:**
```bash
# Все Pod в production
kubectl get pods -l environment=production

# Только frontend приложения
kubectl get pods -l app=frontend

# Pod с версией 1.0
kubectl get pods -l version=1.0

# Pod НЕ в production
kubectl get pods -l environment!=production

# Pod с несколькими метками
kubectl get pods -l 'app in (frontend,backend)'
```

**2. Упражнение: Создайте свои запросы**
```bash
# Найдите все Pod уровня web
kubectl get pods -l 

# Найдите Pod с версией 2.1
kubectl get pods -l 

# Создайте Pod с метками: app=monitoring, tier=monitor, environment=test
```

### 🎯 Задание 2.3: Изменение меток

**1. Добавляем метки существующим Pod:**
```bash
# Добавляем метку emergency=true к frontend
kubectl label pods frontend-app emergency=true

# Изменяем версию backend
kubectl label pods backend-service version=1.1 --overwrite

# Добавляем несколько меток
kubectl label pods database monitoring=true backup-enabled=true
```

**2. Проверяем изменения:**
```bash
# Показать все метки
kubectl get pods --show-labels

# Фильтруем по новым меткам
kubectl get pods -l emergency=true
kubectl get pods -l monitoring=true
```

---

## 🔄 ЧАСТЬ 3: ReplicaSet

### 🎯 Задание 3.1: Создание первого ReplicaSet

**Теория:**
- ReplicaSet гарантирует запуск N копий Pod
- Использует селекторы для поиска своих Pod
- Автоматически восстанавливает количество реплик

**1. Создаем ReplicaSet:**
```yaml
# replicaset-web.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-replicaset
  labels:
    app: web
    tier: frontend
spec:
  replicas: 3  # Хотим 3 идентичных Pod
  selector:
    matchLabels:
      app: web-app  # Ищем Pod с этой меткой
  template:  # Шаблон для создания новых Pod
    metadata:
      labels:
        app: web-app  # Должно совпадать с selector.matchLabels!
        version: "1.0"
        managed-by: replicaset
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
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

**2. Применяем и проверяем:**
```bash
kubectl apply -f replicaset-web.yaml

# Проверяем ReplicaSet
kubectl get replicaset
kubectl describe replicaset web-replicaset

# Проверяем созданные Pod
kubectl get pods -l app=web-app
```

### 🎯 Задание 3.2: Тестирование отказоустойчивости

**1. Имитируем сбой Pod:**
```bash
# Удаляем один из Pod
kubectl delete pod <pod-name>

# Наблюдаем за автоматическим восстановлением
kubectl get pods -l app=web-app -w
```

**2. Масштабируем ReplicaSet:**
```bash
# Увеличиваем до 5 реплик
kubectl scale replicaset web-replicaset --replicas=5

# Уменьшаем до 2 реплик
kubectl scale replicaset web-replicaset --replicas=2

# Проверяем
kubectl get replicaset
kubectl get pods -l app=web-app
```

**3. Упражнение: Изменение через файл**
```bash
# Отредактируйте файл replicaset-web.yaml
# Измените replicas: 4
# Примените изменения
kubectl apply -f replicaset-web.yaml
```

### 🎯 Задание 3.3: Создание ReplicaSet с селекторами

**1. ReplicaSet с сложными селекторами:**
```yaml
# replicaset-api.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: api-replicaset
spec:
  replicas: 2
  selector:
    matchExpressions:
    - key: app
      operator: In
      values:
      - api
      - backend
    - key: environment
      operator: Exists  # Метка должна существовать
  template:
    metadata:
      labels:
        app: api
        environment: staging
        component: microservice
    spec:
      containers:
      - name: api-container
        image: nginx:1.25
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
```

**2. Применяем и тестируем:**
```bash
kubectl apply -f replicaset-api.yaml

# Проверяем селекторы
kubectl describe replicaset api-replicaset

# Создаем Pod который подходит под селектор
kubectl run test-pod --image=nginx:1.25 --labels="app=api,environment=staging"

# Что произойдет с этим Pod?
```

---

## 🚀 ЧАСТЬ 4: Deployment

### 🎯 Задание 4.1: Создание первого Deployment

**Теория:**
- Deployment управляет ReplicaSet
- Предоставляет стратегии обновления
- Поддерживает откаты версий

**1. Создаем Deployment:**
```yaml
# deployment-simple.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-app
  labels:
    app: simple-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: simple-web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: simple-web
        version: "1.0.0"
    spec:
      containers:
      - name: web-server
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
```

**2. Применяем и изучаем:**
```bash
kubectl apply -f deployment-simple.yaml

# Что создал Deployment?
kubectl get all -l app=simple-web

# Смотрим историю развертывания
kubectl rollout history deployment/simple-app
```

### 🎯 Задание 4.2: Стратегии обновления

**1. Обновляем версию приложения:**
```bash
# Способ 1: через kubectl
kubectl set image deployment/simple-app web-server=nginx:1.26

# Наблюдаем за обновлением
kubectl rollout status deployment/simple-app

# Смотрим что произошло
kubectl get pods -l app=simple-web
kubectl get replicaset -l app=simple-web
```

**2. Упражнение: Изменение через файл**
```bash
# Отредактируйте deployment-simple.yaml
# Измените: image: nginx:1.27
# Измените: version: "1.0.1"
# Примените изменения
kubectl apply -f deployment-simple.yaml

# Наблюдайте за процессом
kubectl rollout status deployment/simple-app
```

### 🎯 Задание 4.3: Тестирование стратегий обновления

**1. Создаем Deployment с разными стратегиями:**
```yaml
# deployment-strategies.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-app
spec:
  replicas: 4
  selector:
    matchLabels:
      app: rolling-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Максимум на 2 Pod больше чем replicas
      maxUnavailable: 1  # Максимум 1 Pod недоступен во время обновления
  template:
    metadata:
      labels:
        app: rolling-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
```

**2. Тестируем обновление:**
```bash
kubectl apply -f deployment-strategies.yaml

# Обновляем с наблюдением
kubectl set image deployment/rolling-app app=nginx:1.26

# В другом терминале наблюдаем
kubectl get pods -l app=rolling-app -w

# Сколько Pod одновременно обновляется?
```

### 🎯 Задание 4.4: Откат (Rollback)

**1. Создаем проблемное обновление:**
```bash
# Обновляем на несуществующий образ
kubectl set image deployment/simple-app web-server=nginx:does-not-exist

# Видим проблему
kubectl rollout status deployment/simple-app
kubectl get pods -l app=simple-web
```

**2. Выполняем откат:**
```bash
# Откатываем на предыдущую версию
kubectl rollout undo deployment/simple-app

# Проверяем
kubectl rollout status deployment/simple-app
kubectl get pods -l app=simple-web
```

**3. Работа с историей:**
```bash
# Смотрим полную историю
kubectl rollout history deployment/simple-app --revision=1

# Откатываем на конкретную ревизию
kubectl rollout undo deployment/simple-app --to-revision=1
```

### 🎯 Задание 4.5: Практическое приложение

**1. Создаем многоуровневое приложение:**
```yaml
# full-app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
      tier: web
  template:
    metadata:
      labels:
        app: frontend
        tier: web
        version: "2.3.1"
    spec:
      containers:
      - name: frontend
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
      tier: api
  template:
    metadata:
      labels:
        app: backend
        tier: api
        version: "1.8.0"
    spec:
      containers:
      - name: backend
        image: redis:7-alpine
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "800m"
```

**2. Управляем приложением:**
```bash
kubectl apply -f full-app-deployment.yaml

# Масштабируем frontend
kubectl scale deployment/frontend-deployment --replicas=5

# Обновляем backend
kubectl set image deployment/backend-deployment backend=redis:7.2

# Смотрим общую картину
kubectl get deployments,replicasets,pods --show-labels
```

---

## 🧪 ЧЕК-ЛИСТ ПРОВЕРКИ ЗНАНИЙ

### Проверьте себя:

**✅ Ресурсы:**
- [ ] Могу создать Pod с ограничениями CPU и памяти
- [ ] Понимаю разницу между requests и limits
- [ ] Знаю что происходит при превышении limits

**✅ Метки:**
- [ ] Умею добавлять метки к Pod
- [ ] Могу искать Pod по селекторам
- [ ] Понимаю как использовать matchLabels и matchExpressions

**✅ ReplicaSet:**
- [ ] Могу создать ReplicaSet с указанием реплик
- [ ] Понимаю связь между selector и template labels
- [ ] Знаю как масштабировать ReplicaSet

**✅ Deployment:**
- [ ] Могу создать Deployment со стратегией обновления
- [ ] Умею обновлять приложение разными способами
- [ ] Могу выполнить откат на предыдущую версию
- [ ] Понимаю разницу между Deployment и ReplicaSet

### 🎯 Финальное упражнение:

**Создайте полное приложение:**
```bash
# 1. Создайте Deployment для веб-приложения с 4 репликами
# 2. Установите ресурсы: requests 128Mi/100m, limits 256Mi/500m
# 3. Добавьте метки: app=final-app, environment=production
# 4. Обновите приложение до новой версии
# 5. Масштабируйте до 6 реплик
# 6. Выполните откат на предыдущую версию
```

### 🧹 Очистка:
```bash
# Удаляем все созданные ресурсы
kubectl delete all --all

# Останавливаем Minikube
minikube stop

# Полная очистка (опционально)
minikube delete
```

---



1. **Всегда проверяйте** что создалось: `kubectl get all`
2. **Используйте describe** для диагностики проблем: `kubectl describe <resource>`
3. **Следите за событиями**: `kubectl get events`
4. **Используйте -w** для наблюдения в реальном времени
5. **Не бойтесь ошибок** - они лучший способ обучения!
