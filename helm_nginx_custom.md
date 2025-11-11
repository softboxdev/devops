Создадим свой кастомный чарт с Nginx и установим его через Helm.

## 🎯 **Полный процесс: от образа до установки**

### **Шаг 1: Подготовка окружения**

```bash
# Убедимся что установлены необходимые инструменты
sudo apt update
sudo apt install docker.io helm kubectl -y

# Добавляем пользователя в группу docker (чтобы не использовать sudo)
sudo usermod -aG docker $USER
newgrp docker  # или перелогиньтесь

# Проверяем установку
docker --version
helm version
kubectl version --client
```

### **Шаг 2: Скачиваем образ Nginx**

```bash
# Скачиваем официальный образ Nginx
docker pull nginx:1.25

# Проверяем скачанный образ
docker images nginx

# Можно также скачать Alpine версию (меньше размер)
docker pull nginx:1.25-alpine
```

### **Шаг 3: Создаем свой Helm чарт**

```bash
# Создаем структуру каталогов для чарта
mkdir -p ~/my-nginx-chart
cd ~/my-nginx-chart

# Создаем базовую структуру Helm чарта
helm create my-nginx

# Смотрим что создалось
ls -la my-nginx/
```

**Структура чарта:**
```
my-nginx/
├── Chart.yaml          # Метаданные чарта
├── values.yaml         # Значения по умолчанию
├── templates/          # Шаблоны Kubernetes
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── _helpers.tpl
└── charts/             # Зависимости
```

### **Шаг 4: Настраиваем наш чарт**

**Редактируем `Chart.yaml`:**
```bash
nano my-nginx/Chart.yaml
```

```yaml
apiVersion: v2
name: my-nginx
description: A custom Nginx Helm chart for Ubuntu
type: application
version: 0.1.0
appVersion: "1.25"

# Дополнительные метаданные (опционально)
maintainers:
  - name: your-name
    email: your-email@example.com
```

**Редактируем `values.yaml`:**
```bash
nano my-nginx/values.yaml
```

```yaml
# Default values for my-nginx
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25"

nameOverride: ""
fullnameOverride: ""

service:
  type: ClusterIP
  port: 80
  targetPort: 80

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}
```

### **Шаг 5: Кастомизируем Deployment**

```bash
# Редактируем deployment template
nano my-nginx/templates/deployment.yaml
```

**Упрощенная версия (можно оставить как есть или модифицировать):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-nginx.fullname" . }}
  labels:
    {{- include "my-nginx.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "my-nginx.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-nginx.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: nginx
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /
              port: http
          readinessProbe:
            httpGet:
              path: /
              port: http
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### **Шаг 6: Упаковываем чарт**

```bash
# Переходим в директорию чарта
cd my-nginx

# Проверяем валидность чарта
helm lint .

# Пробный рендер шаблонов (чтобы увидеть что получится)
helm template . --debug

# Упаковываем чарт в .tgz архив
helm package .

# Проверяем что архив создался
ls -la *.tgz
```

### **Шаг 7: Устанавливаем наш чарт**

**Вариант A: Установка из локальной директории**
```bash
# Устанавливаем напрямую из директории
helm install my-nginx-release ./
```

**Вариант B: Установка из упакованного .tgz файла**
```bash
# Устанавливаем из архива
helm install my-nginx-release ./my-nginx-0.1.0.tgz
```

**Вариант C: Создаем свой репозиторий**
```bash
# Создаем директорию для репозитория
mkdir ~/my-helm-repo
cp my-nginx-0.1.0.tgz ~/my-helm-repo/

# Генерируем index.yaml для репозитория
helm repo index ~/my-helm-repo/ --url https://raw.githubusercontent.com/your-username/your-repo/main

# Добавляем локальный репозиторий
helm repo add my-repo file:///home/administrator/my-helm-repo

# Обновляем индекс
helm repo update

# Устанавливаем из своего репозитория
helm install my-nginx-release my-repo/my-nginx
```

### **Шаг 8: Проверяем установку**

```bash
# Проверяем релиз
helm list

# Проверяем поды
kubectl get pods -l app.kubernetes.io/name=my-nginx

# Проверяем сервис
kubectl get services

# Смотрим логи
kubectl logs -l app.kubernetes.io/name=my-nginx

# Проверяем развертывание
kubectl get deployments
```

### **Шаг 9: Тестируем наше приложение**

```bash
# Пробрасываем порт для локального тестирования
kubectl port-forward service/my-nginx-my-nginx 8080:80

# В другом терминале проверяем
curl http://localhost:8080
```

## 🚀 **Продвинутая кастомизация**

### **Добавляем ConfigMap для кастомной конфигурации Nginx**

**Создаем шаблон `templates/configmap.yaml`:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "my-nginx.fullname" . }}-config
  labels:
    {{- include "my-nginx.labels" . | nindent 4 }}
data:
  nginx.conf: |
    server {
        listen 80;
        server_name _;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
```

**Обновляем `deployment.yaml` чтобы использовать ConfigMap:**
```yaml
# В секции containers добавляем volumeMounts:
volumeMounts:
  - name: nginx-config
    mountPath: /etc/nginx/conf.d/default.conf
    subPath: nginx.conf

# В spec template добавляем volumes:
volumes:
  - name: nginx-config
    configMap:
      name: {{ include "my-nginx.fullname" . }}-config
```

## 📝 **Практический пример: Установка с кастомными значениями**

**Создаем файл с кастомными значениями `custom-values.yaml`:**
```yaml
replicaCount: 3

image:
  repository: nginx
  tag: "1.25-alpine"

service:
  type: LoadBalancer
  port: 80

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

**Устанавливаем с кастомными значениями:**
```bash
helm install my-nginx-release ./ -f custom-values.yaml
```

## 🛠️ **Полезные команды для управления**

```bash
# Обновление релиза
helm upgrade my-nginx-release ./

# История релиза
helm history my-nginx-release

# Откат к предыдущей версии
helm rollback my-nginx-release 1

# Удаление релиза
helm uninstall my-nginx-release

# Просмотр установленных значений
helm get values my-nginx-release
```

## 🎯 **Итоговый рабочий процесс**

1. **Скачали образ**: `docker pull nginx:1.25`
2. **Создали чарт**: `helm create my-nginx` 
3. **Настроили под свои нужды**: редактировали `values.yaml` и шаблоны
4. **Упаковали**: `helm package .`
5. **Установили**: `helm install my-nginx-release ./`

**Теперь у вас есть собственный Helm чарт с Nginx, который можно устанавливать, обновлять и распространять!** 🚀