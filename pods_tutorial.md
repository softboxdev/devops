# Минимальный проект Kubernetes на Ubuntu 24.04 для обучения

## Шаг 1: Установка Kubernetes (Minikube)

### Устанавливаем Minikube - минимальный Kubernetes
```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Устанавливаем Docker
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Перезапускаем сессию (выйти и зайти обратно)
# Или выполнить:
newgrp docker

# Устанавливаем Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# Устанавливаем kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
```

### Запускаем Minikube
```bash
# Запускаем кластер
minikube start --driver=docker

# Проверяем статус
minikube status
kubectl get nodes
```

---

## Шаг 2: Создаем первый Pod вручную

### Создаем файл `simple-pod.yaml`
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

### Применяем и проверяем
```bash
# Создаем Pod
kubectl apply -f simple-pod.yaml

# Смотрим все Pod'ы
kubectl get pods

# Смотрим подробную информацию
kubectl describe pod my-first-pod

# Смотрим логи
kubectl logs my-first-pod

# Заходим внутрь Pod'а
kubectl exec -it my-first-pod -- /bin/sh
# внутри Pod'а:
# ls -la
# cat /etc/nginx/nginx.conf
# exit
```

---

## Шаг 3: Создаем несколько Pod'ов для практики

### Создаем файл `multiple-pods.yaml`
```yaml
# Pod 1 - Веб сервер
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
  labels:
    app: web
    type: frontend
spec:
  containers:
  - name: web-container
    image: nginx:alpine
    ports:
    - containerPort: 80

---
# Pod 2 - База данных
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
  labels:
    app: database
    type: backend
spec:
  containers:
  - name: db-container
    image: postgres:13-alpine
    ports:
    - containerPort: 5432
    env:
    - name: POSTGRES_PASSWORD
      value: "password123"

---
# Pod 3 - Приложение
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  labels:
    app: application
    type: backend
spec:
  containers:
  - name: app-container
    image: busybox:latest
    command: ['sh', '-c', 'echo "Hello Kubernetes!" && sleep 3600']
```

### Работаем с несколькими Pod'ами
```bash
# Создаем все Pod'ы
kubectl apply -f multiple-pods.yaml

# Смотрим все Pod'ы
kubectl get pods

# Смотрим Pod'ы с фильтрацией по меткам
kubectl get pods -l app=web
kubectl get pods -l type=backend

# Смотрим подробную информацию о конкретном Pod'е
kubectl describe pod web-pod

# Проверяем логи разных Pod'ов
kubectl logs web-pod
kubectl logs app-pod

# Удаляем конкретный Pod
kubectl delete pod app-pod

# Удаляем все Pod'ы из файла
kubectl delete -f multiple-pods.yaml
```

---

## Шаг 4: Создаем Deployment для управления Pod'ами

### Создаем файл `deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-web-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
        version: "1.0"
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: NGINX_PORT
          value: "80"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
```

### Управляем Deployment
```bash
# Создаем Deployment
kubectl apply -f deployment.yaml

# Смотрим Deployment
kubectl get deployment
kubectl describe deployment my-web-deployment

# Смотрим Pod'ы созданные Deployment'ом
kubectl get pods -l app=web-app

# Масштабируем Deployment
kubectl scale deployment my-web-deployment --replicas=5
kubectl get pods

# Обновляем образ
kubectl set image deployment/my-web-deployment nginx=nginx:1.19-alpine

# Смотрим историю обновлений
kubectl rollout history deployment/my-web-deployment

# Откатываем обновление
kubectl rollout undo deployment/my-web-deployment

# Удаляем Deployment (автоматически удаляет все Pod'ы)
kubectl delete deployment my-web-deployment
```

---

## Шаг 5: Создаем Service для доступа к Pod'ам

### Создаем файл `service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  selector:
    app: web-app
  ports:
  - name: http
    port: 80
    targetPort: 80
  type: LoadBalancer
```

### Тестируем Service
```bash
# Создаем Deployment если еще нет
kubectl apply -f deployment.yaml

# Создаем Service
kubectl apply -f service.yaml

# Смотрим Service
kubectl get service
kubectl describe service web-service

# Получаем доступ к приложению
minikube service web-service

# Или получаем URL
minikube service web-service --url

# Тестируем изнутри кластера
kubectl run test-pod --image=busybox -it --rm -- /bin/sh
# внутри test-pod:
# wget -qO- http://web-service:80
# exit
```

---

## Шаг 6: Практические упражнения

### Упражнение 1: Создай Pod с BusyBox
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exercise-1
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ['sh', '-c', 'echo "Мой первый Pod!" && sleep 3600']
```

**Задачи:**
1. Создай Pod
2. Посмотри его логи
3. Зайди внутрь и создай файл
4. Удали Pod

### Упражнение 2: Создай Deployment с 2 репликами
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exercise-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: exercise
  template:
    metadata:
      labels:
        app: exercise
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
```

**Задачи:**
1. Создай Deployment
2. Убедись что 2 Pod'а работают
3. Масштабируй до 4 реплик
4. Обнови образ на nginx:1.19
5. Откати обновление

---

## Шаг 7: Полезные команды для обучения

```bash
# Основные команды просмотра
kubectl get all                          # Все ресурсы
kubectl get pods --watch                 # Следить за изменением Pod'ов
kubectl get pods -o wide                 Подробная информация о Pod'ах

# Отладка
kubectl logs <pod-name>                  # Логи Pod'а
kubectl logs <pod-name> -f               # Логи в реальном времени
kubectl exec -it <pod-name> -- /bin/sh   # Зайти внутрь Pod'а

# Операции
kubectl apply -f file.yaml               # Создать/обновить ресурсы
kubectl delete -f file.yaml              # Удалить ресурсы
kubectl delete pod <pod-name>            # Удалить конкретный Pod

# Информация о кластере
kubectl cluster-info                     # Информация о кластере
kubectl get nodes                        # Список узлов
minikube dashboard                       # Веб-панель управления
```

---

## Шаг 8: Создаем учебный проект

### Структура проекта:
```
kubernetes-learning/
├── pods/
│   ├── simple-pod.yaml
│   └── multiple-pods.yaml
├── deployments/
│   ├── deployment.yaml
│   └── service.yaml
└── exercises/
    ├── exercise-1.yaml
    └── exercise-2.yaml
```

### Полный сценарий обучения:

1. **Начало работы:**
   ```bash
   minikube start
   kubectl get nodes
   ```

2. **Простые Pod'ы:**
   ```bash
   kubectl apply -f pods/simple-pod.yaml
   kubectl get pods
   kubectl describe pod my-first-pod
   ```

3. **Множество