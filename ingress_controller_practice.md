
# 🌐 Практическое руководство по Kubernetes: Ingress, Cert-manager и финальное задание

## 📋 Предварительная настройка

### 1. Запуск Minikube с необходимыми аддонами

```bash
# Запускаем Minikube с дополнительными функциями
minikube start --memory=4096 --cpus=2 --addons=ingress --addons=metrics-server

# Проверяем
kubectl get nodes
minikube status

# Создаем рабочую директорию
mkdir ~/k8s-ingress-practice && cd ~/k8s-ingress-practice

# Проверяем что ingress аддон включен
minikube addons list | grep ingress
```

### 2. Проверка установленного Ingress Controller

```bash
# Смотрим какие Pod работают в namespace ingress-nginx
kubectl get pods -n ingress-nginx

# Проверяем сервис ingress-nginx
kubectl get svc -n ingress-nginx

# Смотрим что LoadBalancer есть
kubectl describe svc ingress-nginx-controller -n ingress-nginx
```

---

## 🚪 ЧАСТЬ 1: Ingress Controller и базовые маршруты

### 🎯 Задание 1.1: Подготовка тестовых приложений

**Теория:**
- **Ingress** - это API объект который управляет внешним доступом к сервисам
- **Ingress Controller** - это Pod который обрабатывает Ingress правила
- **Minikube** уже имеет встроенный Nginx Ingress Controller

**1. Создаем два простых веб-приложения:**
```yaml
# deployment-apps.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: content
        configMap:
          name: frontend-content
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: content
        configMap:
          name: backend-content
```

**2. Создаем контент для приложений:**
```yaml
# configmap-content.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Frontend App</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #e3f2fd; }
            .container { max-width: 800px; margin: 0 auto; padding: 20px; background: white; border-radius: 10px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Frontend Application</h1>
            <p>Это фронтенд приложение доступное через Ingress</p>
            <p><strong>Host:</strong> frontend.k8s-practice.local</p>
            <p><strong>Path:</strong> /</p>
        </div>
    </body>
    </html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Backend API</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background: #f3e5f5; }
            .container { max-width: 800px; margin: 0 auto; padding: 20px; background: white; border-radius: 10px; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🔧 Backend API</h1>
            <p>Это бэкенд API доступное через Ingress</p>
            <p><strong>Host:</strong> backend.k8s-practice.local</p>
            <p><strong>Path:</strong> /api/</p>
            <p><strong>Примеры эндпоинтов:</strong></p>
            <ul>
                <li><a href="/api/users">/api/users</a></li>
                <li><a href="/api/products">/api/products</a></li>
            </ul>
        </div>
    </body>
    </html>
```

**3. Создаем сервисы для приложений:**
```yaml
# services.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
```

**4. Применяем все ресурсы:**
```bash
kubectl apply -f deployment-apps.yaml -f configmap-content.yaml -f services.yaml

# Проверяем что все запустилось
kubectl get pods,svc
```

### 🎯 Задание 1.2: Создание первого Ingress

**1. Создаем базовый Ingress ресурс:**
```yaml
# ingress-basic.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basic-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: frontend.k8s-practice.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
  - host: backend.k8s-practice.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 80
```

**2. Применяем и тестируем:**
```bash
kubectl apply -f ingress-basic.yaml

# Проверяем Ingress
kubectl get ingress

# Смотрим детали
kubectl describe ingress basic-ingress

# Получаем IP адрес Ingress
kubectl get svc -n ingress-nginx

# Тестируем (нужно настроить hosts файл или использовать curl с заголовком)
minikube ip
# Запишите этот IP - он понадобится для тестирования
```

### 🎯 Задание 1.3: Тестирование Ingress

**1. Настраиваем локальный hosts файл:**
```bash
# Получаем IP Minikube
MINIKUBE_IP=$(minikube ip)
echo "Minikube IP: $MINIKUBE_IP"

# Добавляем в /etc/hosts (потребуются права sudo)
echo "$MINIKUBE_IP frontend.k8s-practice.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP backend.k8s-practice.local" | sudo tee -a /etc/hosts

# Проверяем
cat /etc/hosts | grep k8s-practice.local
```

**2. Альтернативный способ - тестирование через curl:**
```bash
# Тестируем без настройки hosts
MINIKUBE_IP=$(minikube ip)

# Frontend приложение
curl -H "Host: frontend.k8s-practice.local" http://$MINIKUBE_IP

# Backend приложение  
curl -H "Host: backend.k8s-practice.local" http://$MINIKUBE_IP

# Или используем встроенную функцию Minikube
minikube service ingress-nginx-controller -n ingress-nginx --url
```

**3. Упражнение: Проверка в браузере**
```bash
# Открываем в браузере
echo "Откройте в браузере:"
echo "http://frontend.k8s-practice.local"
echo "http://backend.k8s-practice.local"
```

---

## 🛣️ ЧАСТЬ 2: Продвинутые возможности Ingress

### 🎯 Задание 2.1: Path-based маршрутизация

**1. Создаем приложение с разными путями:**
```yaml
# deployment-multi-path.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-path-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-path
  template:
    metadata:
      labels:
        app: multi-path
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: content
        configMap:
          name: multi-path-content
---
apiVersion: v1
kind: Service
metadata:
  name: multi-path-service
spec:
  selector:
    app: multi-path
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: multi-path-content
data:
  index.html: |
    <html><body><h1>Main Page</h1><p>Главная страница</p></body></html>
  api.html: |
    <html><body><h1>API Documentation</h1><p>Документация API</p></body></html>
  admin.html: |
    <html><body><h1>Admin Panel</h1><p>Панель администратора</p></body></html>
```

**2. Создаем Ingress с разными путями:**
```yaml
# ingress-paths.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: app.k8s-practice.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: multi-path-service
            port:
              number: 80
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: multi-path-service
            port:
              number: 80
      - path: /admin(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: multi-path-service
            port:
              number: 80
```

**3. Тестируем:**
```bash
kubectl apply -f deployment-multi-path.yaml -f ingress-paths.yaml

# Добавляем host в /etc/hosts
echo "$(minikube ip) app.k8s-practice.local" | sudo tee -a /etc/hosts

# Тестируем разные пути
curl http://app.k8s-practice.local/
curl http://app.k8s-practice.local/api
curl http://app.k8s-practice.local/admin
```

### 🎯 Задание 2.2: Аннотации и настройки Nginx

**1. Создаем Ingress с кастомными аннотациями:**
```yaml
# ingress-annotations.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: annotated-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "X-Custom-Header: K8s-Practice";
spec:
  rules:
  - host: custom.k8s-practice.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

**2. Тестируем кастомные заголовки:**
```bash
kubectl apply -f ingress-annotations.yaml

# Добавляем host
echo "$(minikube ip) custom.k8s-practice.local" | sudo tee -a /etc/hosts

# Проверяем заголовки
curl -I http://custom.k8s-practice.local/

# Должны увидеть X-Custom-Header
curl -v http://custom.k8s-practice.local/ 2>&1 | grep -i "x-custom"
```

---

## 🔐 ЧАСТЬ 3: Cert-manager и SSL сертификаты

### 🎯 Задание 3.1: Установка Cert-manager

**Теория:**
- **Cert-manager** автоматически получает и обновляет SSL сертификаты
- Работает с Let's Encrypt для бесплатных сертификатов
- В Minikube будем использовать self-signed сертификаты для практики

**1. Устанавливаем Cert-manager:**
```bash
# Добавляем репозиторий Jetstack
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Устанавливаем Cert-manager
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.13.0 \
  --set installCRDs=true

# Ждем запуска
kubectl get pods -n cert-manager --watch
```

**2. Альтернативная установка (если нет helm):**
```bash
# Устанавливаем через manifest
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Проверяем
kubectl get pods -n cert-manager -w
```

### 🎯 Задание 3.2: Создание Self-Signed сертификатов

**1. Создаем Issuer для self-signed сертификатов:**
```yaml
# issuer-selfsigned.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
```

**2. Создаем SSL сертификат:**
```yaml
# certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: k8s-practice-tls
  namespace: default
spec:
  secretName: k8s-practice-tls-secret
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days
  subject:
    organizations:
    - K8s Practice
  commonName: k8s-practice.local
  isCA: false
  privateKey:
    algorithm: RSA
    encoding: PKCS1
    size: 2048
  usages:
  - server auth
  - client auth
  dnsNames:
  - secure.k8s-practice.local
  - frontend.k8s-practice.local
  - backend.k8s-practice.local
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
```

**3. Применяем и проверяем:**
```bash
kubectl apply -f issuer-selfsigned.yaml -f certificate.yaml

# Проверяем Issuer
kubectl get clusterissuer

# Проверяем Certificate
kubectl get certificate

# Проверяем Secret с сертификатом
kubectl get secret k8s-practice-tls-secret

# Смотрим детали сертификата
kubectl describe certificate k8s-practice-tls
```

### 🎯 Задание 3.3: Ingress с SSL/TLS

**1. Создаем Ingress с TLS:**
```yaml
# ingress-tls.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  tls:
  - hosts:
    - secure.k8s-practice.local
    secretName: k8s-practice-tls-secret
  rules:
  - host: secure.k8s-practice.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

**2. Тестируем HTTPS:**
```bash
kubectl apply -f ingress-tls.yaml

# Добавляем host
echo "$(minikube ip) secure.k8s-practice.local" | sudo tee -a /etc/hosts

# Пробуем подключиться по HTTPS (будет предупреждение о self-signed)
curl -k https://secure.k8s-practice.local

# Смотрим детали сертификата
curl -kv https://secure.k8s-practice.local 2>&1 | grep -A 10 "SSL certificate"

# Игнорируем ошибку SSL - это нормально для self-signed сертификатов
```

---

## 🎯 ФИНАЛЬНОЕ ЗАДАНИЕ: Полноценное приложение

### 🎯 Задание 4.1: Развертывание многоуровневого приложения

**1. Создаем все компоненты приложения:**
```yaml
# final-app.yaml
---
# Database Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
spec:
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: "k8sapp"
        - name: POSTGRES_USER
          value: "appuser"
        - name: POSTGRES_PASSWORD
          value: "apppass123"
        ports:
        - containerPort: 5432
---
# Backend API Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend-api
  template:
    metadata:
      labels:
        app: backend-api
    spec:
      containers:
      - name: api
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: api-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: api-content
        configMap:
          name: api-content
---
# Frontend Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: frontend-content
          mountPath: /usr/share/nginx/html
      volumes:
      - name: frontend-content
        configMap:
          name: frontend-content
---
# Services
apiVersion: v1
kind: Service
metadata:
  name: database-service
spec:
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service-final
spec:
  selector:
    app: backend-api
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service-final
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
# ConfigMaps
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Backend API</title></head>
    <body style="font-family: Arial; margin: 40px; background: #f0f8ff;">
      <div style="max-width: 800px; margin: 0 auto; padding: 20px; background: white; border-radius: 10px;">
        <h1>🔧 Backend API Service</h1>
        <p><strong>Status:</strong> 🟢 Running</p>
        <p><strong>Database:</strong> Connected</p>
        <p><strong>Endpoints:</strong></p>
        <ul>
          <li><code>/api/v1/users</code></li>
          <li><code>/api/v1/products</code></li>
          <li><code>/api/v1/orders</code></li>
        </ul>
      </div>
    </body>
    </html>
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-content
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>K8s Final App</title></head>
    <body style="font-family: Arial; margin: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);">
      <div style="min-height: 100vh; display: flex; align-items: center; justify-content: center;">
        <div style="background: white; padding: 40px; border-radius: 15px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); text-align: center;">
          <h1 style="color: #333; margin-bottom: 20px;">🎉 Kubernetes Final Application</h1>
          <p style="color: #666; font-size: 18px; margin-bottom: 30px;">Успешно развернуто с использованием:</p>
          <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin-bottom: 30px;">
            <div style="padding: 15px; background: #f8f9fa; border-radius: 8px;">🚀 Deployments</div>
            <div style="padding: 15px; background: #f8f9fa; border-radius: 8px;">🔗 Services</div>
            <div style="padding: 15px; background: #f8f9fa; border-radius: 8px;">🌐 Ingress</div>
            <div style="padding: 15px; background: #f8f9fa; border-radius: 8px;">🔐 SSL/TLS</div>
          </div>
          <p style="color: #28a745; font-weight: bold;">✅ Все компоненты работают!</p>
        </div>
      </div>
    </body>
    </html>
```

**2. Создаем финальный Ingress:**
```yaml
# final-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: final-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  tls:
  - hosts:
    - app.k8s-final.local
    - api.k8s-final.local
    secretName: k8s-practice-tls-secret
  rules:
  - host: app.k8s-final.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service-final
            port:
              number: 80
  - host: api.k8s-final.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-service-final
            port:
              number: 80
```

**3. Развертываем и тестируем:**
```bash
# Применяем все ресурсы
kubectl apply -f final-app.yaml -f final-ingress.yaml

# Добавляем hosts
MINIKUBE_IP=$(minikube ip)
echo "$MINIKUBE_IP app.k8s-final.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP api.k8s-final.local" | sudo tee -a /etc/hosts

# Ждем запуска
kubectl get pods -w

# Тестируем
echo "Тестируем приложение:"
echo "Frontend (HTTP): http://app.k8s-final.local"
echo "Frontend (HTTPS): https://app.k8s-final.local"
echo "Backend API (HTTP): http://api.k8s-final.local" 
echo "Backend API (HTTPS): https://api.k8s-final.local"

# Быстрая проверка
curl -k https://app.k8s-final.local
curl -k https://api.k8s-final.local
```

### 🎯 Задание 4.2: Мониторинг и проверка

**1. Проверяем все компоненты:**
```bash
# Проверяем все ресурсы
kubectl get all

# Проверяем Ingress
kubectl get ingress

# Проверяем сертификаты
kubectl get certificate

# Проверяем логи Ingress Controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=10

# Проверяем логи Cert-manager
kubectl logs -n cert-manager deployment/cert-manager --tail=10
```

**2. Упражнение: Тестирование отказоустойчивости**
```bash
# Удаляем один из Pod фронтенда
kubectl delete pod -l app=frontend --force

# Проверяем что приложение продолжает работать
curl -k https://app.k8s-final.local

# Масштабируем бэкенд
kubectl scale deployment/backend-api --replicas=3

# Проверяем
kubectl get pods -l app=backend-api
```

---

## 🧪 ЧЕК-ЛИСТ ПРОВЕРКИ ЗНАНИЙ

### Проверьте себя:

**✅ Ingress Controller:**
- [ ] Понимаю что такое Ingress и Ingress Controller
- [ ] Могу создать базовый Ingress с host-based маршрутизацией
- [ ] Умею настраивать path-based маршрутизацию
- [ ] Знаю как тестировать Ingress правила

**✅ Cert-manager и SSL:**
- [ ] Понимаю для чего нужен Cert-manager
- [ ] Могу создать ClusterIssuer для self-signed сертификатов
- [ ] Умею создавать SSL сертификаты
- [ ] Могу настроить Ingress с TLS терминацией

**✅ Финальное приложение:**
- [ ] Могу развернуть многоуровневое приложение
- [ ] Умею настраивать маршрутизацию между компонентами
- [ ] Понимаю как работает SSL терминация на Ingress
- [ ] Знаю как проверить работоспособность всех компонентов

### 🧹 Очистка:
```bash
# Удаляем все созданные ресурсы
kubectl delete all --all
kubectl delete ingress --all
kubectl delete certificate --all
kubectl delete clusterissuer --all
kubectl delete configmap --all

# Удаляем hosts записи
sudo sed -i '/k8s-practice.local/d' /etc/hosts
sudo sed -i '/k8s-final.local/d' /etc/hosts

# Останавливаем Minikube
minikube stop

# Полная очистка (опционально)
minikube delete
```

---

## 💡 ПОЛЕЗНЫЕ КОМАНДЫ ДЛЯ РАБОТЫ

```bash
# Мониторинг Ingress
kubectl get ingress
kubectl describe ingress <name>

# Проверка сертификатов
kubectl get certificate
kubectl describe certificate <name>

# Логи Ingress Controller
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller -f

# Логи Cert-manager
kubectl logs -n cert-manager deployment/cert-manager -f

# Проверка SSL соединения
openssl s_client -connect app.k8s-final.local:443 -servername app.k8s-final.local
```

## ⚠️ ВАЖНЫЕ МОМЕНТЫ 

1. **Ingress Controller** должен быть запущен до создания Ingress ресурсов
2. **Hosts файл** нужно настраивать для тестирования доменных имен
3. **Self-signed сертификаты** вызывают предупреждения в браузере - это нормально
4. **Cert-manager** для продакшена требует настройки реального Issuer (Let's Encrypt)
5. **Всегда проверяйте** логи Ingress Controller при проблемах с маршрутизацией
