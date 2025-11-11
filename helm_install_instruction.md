# Установка Helm на Ubuntu 22.04 и основы работы

## Установка Helm

### Способ 1: Установка из официального репозитория (рекомендуется)

```bash
# Обновление пакетов
sudo apt update

# Установка curl если не установлен
sudo apt install curl -y

# Скачивание установочного скрипта Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Проверка установки
helm version
```

### Способ 2: Установка из бинарного файла

```bash
# Скачивание последней версии Helm - проверьте версию на сайта и подставьте свое значение
wget https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz

# Распаковка архива - укажите свой файл
tar -zxvf helm-v3.14.0-linux-amd64.tar.gz

# Перемещение бинарного файла
sudo mv linux-amd64/helm /usr/local/bin/helm

# Проверка установки
helm version
```

### Способ 3: Установка через snap

```bash
sudo snap install helm --classic
```

## Базовые упражнения для освоения Helm

### 1. Добавление репозиториев - если недоступен, то воспользуйтесь Elastic

```bash
# Добавление стабильного репозитория
helm repo add bitnami https://charts.bitnami.com/bitnami

# Обновление информации о репозиториях
helm repo update

# Просмотр списка репозиториев
helm repo list
```

### 2. Поиск charts

```bash
# Поиск nginx в репозиториях
helm search repo nginx

# Поиск wordpress
helm search repo wordpress

# Поиск с фильтром по репозиторию
helm search repo bitnami/nginx
```

### 3. Установка и управление релизами

```bash
# Установка nginx
helm install my-nginx bitnami/nginx

# Просмотр установленных релизов
helm list

# Просмотр статуса релиза
helm status my-nginx

# Обновление релиза
helm upgrade my-nginx bitnami/nginx

# Удаление релиза
helm uninstall my-nginx
```

### 4. Работа с values

```bash
# Просмотр значений по умолчанию
helm show values bitnami/nginx

# Сохранение значений в файл для кастомизации
helm show values bitnami/nginx > nginx-values.yaml

# Установка с кастомными значениями
helm install my-nginx bitnami/nginx -f nginx-values.yaml

# Установка с переопределением отдельных параметров
helm install my-nginx bitnami/nginx --set service.type=NodePort
```
# Установка Helm на Ubuntu 22.04 и работа с Elastic Stack

## Установка Helm

### Способ 1: Установка из официального репозитория (рекомендуется)

```bash
# Обновление пакетов
sudo apt update

# Установка curl если не установлен
sudo apt install curl -y

# Скачивание установочного скрипта Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Проверка установки
helm version
```

### Способ 2: Установка из бинарного файла

```bash
# Скачивание последней версии Helm (проверьте актуальную версию на GitHub)
wget https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz

# Распаковка архива
tar -zxvf helm-v3.14.0-linux-amd64.tar.gz

# Перемещение бинарного файла
sudo mv linux-amd64/helm /usr/local/bin/helm

# Проверка установки
helm version
```

### Способ 3: Установка через snap

```bash
sudo snap install helm --classic
```

## Базовые упражнения для освоения Helm

### 1. Добавление репозитория Elastic

```bash
# Добавление официального репозитория Elastic
helm repo add elastic https://helm.elastic.co

# Обновление информации о репозиториях
helm repo update

# Просмотр списка репозиториев
helm repo list
```

### 2. Поиск charts Elastic Stack

```bash
# Поиск всех charts в репозитории Elastic
helm search repo elastic/

# Поиск Elasticsearch
helm search repo elastic/elasticsearch

# Поиск Kibana
helm search repo elastic/kibana

# Поиск Logstash
helm search repo elastic/logstash

# Поиск Filebeat
helm search repo elastic/filebeat
```

### 3. Установка и управление релизами

```bash
# Установка Elasticsearch
helm install my-elasticsearch elastic/elasticsearch

# Просмотр установленных релизов
helm list

# Просмотр статуса релиза
helm status my-elasticsearch

# Обновление релиза
helm upgrade my-elasticsearch elastic/elasticsearch

# Удаление релиза
helm uninstall my-elasticsearch
```

# 1. Установка Minikube -  в случае если кластер недоступен

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# 2. Запуск кластера
minikube start --driver=docker

# 3. Проверка кластера
kubectl get nodes

# 4. Добавление репозитория Elastic
helm repo add elastic https://helm.elastic.co
helm repo update

# 5. Теперь установка Elasticsearch
helm install my-elasticsearch elastic/elasticsearch

# 6. Проверка установки
helm list
kubectl get pods

### 4. Работа с values

```bash
# Просмотр значений по умолчанию для Elasticsearch
helm show values elastic/elasticsearch

# Сохранение значений в файл для кастомизации
helm show values elastic/elasticsearch > elasticsearch-values.yaml

# Установка с кастомными значениями
helm install my-elasticsearch elastic/elasticsearch -f elasticsearch-values.yaml

# Установка с переопределением отдельных параметров
helm install my-elasticsearch elastic/elasticsearch \
  --set replicas=2 \
  --set resources.requests.memory=1Gi
```

## Создание своего Helm Chart

### 1. Создание структуры chart

```bash
# Создание нового chart
helm create myapp-chart

# Просмотр структуры созданного chart
tree myapp-chart/
```

Структура chart:
```
myapp-chart/
├── Chart.yaml          # Метаинформация о chart
├── values.yaml         # Значения по умолчанию
├── templates/          # Шаблоны Kubernetes манифестов
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── serviceaccount.yaml
│   ├── _helpers.tpl    # Вспомогательные шаблоны
│   └── tests/
│       └── test-connection.yaml
└── charts/             # Зависимости (subcharts)
```

### 2. Пример простого Chart для веб-приложения

**Chart.yaml:**
```yaml
apiVersion: v2
name: my-webapp
description: A simple web application Helm chart
type: application
version: 0.1.0
appVersion: "1.0"
```

**values.yaml:**
```yaml
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25"

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: ""
  hosts:
    - host: myapp.local
      paths:
        - path: /
          pathType: Prefix

resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
```

**templates/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-webapp.fullname" . }}
  labels:
    {{- include "my-webapp.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "my-webapp.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-webapp.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

**templates/service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "my-webapp.fullname" . }}
  labels:
    {{- include "my-webapp.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "my-webapp.selectorLabels" . | nindent 4 }}
```

### 3. Тестирование и установка своего Chart

```bash
# Проверка синтаксиса шаблонов
helm lint myapp-chart

# Тестовый рендеринг шаблонов
helm template myapp-chart

# Установка в кластер
helm install my-release ./myapp-chart

# Установка с кастомными значениями
helm install my-release ./myapp-chart --set replicaCount=3

# Создание package
helm package myapp-chart
```

## Практические упражнения с Elastic Stack

### Упражнение 1: Установка Elasticsearch и Kibana

```bash
# Установка Elasticsearch с кастомными настройками
helm install elasticsearch elastic/elasticsearch \
  --set replicas=2 \
  --set resources.requests.memory=1Gi \
  --set resources.limits.memory=2Gi

# Установка Kibana
helm install kibana elastic/kibana \
  --set service.type=LoadBalancer

# Проверка установки
kubectl get pods -l app=elasticsearch-master
kubectl get pods -l app=kibana
```

### Упражнение 2: Установка Filebeat для сбора логов

```bash
# Просмотр значений Filebeat
helm show values elastic/filebeat

# Установка Filebeat
helm install filebeat elastic/filebeat \
  --set daemonset.enabled=true \
  --set daemonset.filebeatConfig.filebeat.yml="
filebeat.inputs:
- type: container
  paths:
    - /var/log/containers/*.log
output.elasticsearch:
  hosts: ['elasticsearch-master:9200']
"

# Проверка логов
kubectl logs -l app=filebeat
```

### Упражнение 3: Создание Chart для приложения с Elasticsearch зависимостью

Создайте `Chart.yaml` с зависимостями:

```yaml
apiVersion: v2
name: my-app-with-elastic
description: Application with Elasticsearch dependency
type: application
version: 0.1.0
appVersion: "1.0"
dependencies:
  - name: elasticsearch
    version: "8.5.1"
    repository: "https://helm.elastic.co"
    condition: elasticsearch.enabled
```

**values.yaml:**
```yaml
elasticsearch:
  enabled: true
  replicas: 1
  resources:
    requests:
      memory: "1Gi"
    limits:
      memory: "2Gi"

app:
  replicaCount: 2
  image:
    repository: nginx
    tag: "1.25"
```

```bash
# Скачивание зависимостей
helm dependency update

# Установка с зависимостями
helm install my-app-with-elastic .
```

## Полезные команды для повседневной работы

```bash
# Просмотр истории релиза
helm history my-release

# Откат к предыдущей версии
helm rollback my-release 1

# Просмотр всех манифестов установленного релиза
helm get manifest my-release

# Просмотр значений установленного релиза
helm get values my-release

# Дебаг шаблонов
helm install --dry-run --debug my-release ./my-chart

# Просмотр списка установленных charts
helm list --all-namespaces

# Удаление релиза с сохранением истории
helm uninstall my-release --keep-history
```

## Советы по работе с Helm

1. **Всегда используйте `--dry-run --debug`** перед установкой для проверки
2. **Версионируйте свои charts** с помощью семантического версионирования
3. **Используйте `helm dependency update`** при изменении зависимостей
4. **Храните values файлы** в системе контроля версий
5. **Используйте `helm template`** для генерации манифестов в CI/CD
6. **Для продакшена настраивайте ресурсы** и лимиты для Elasticsearch
7. **Используйте persistence** для данных Elasticsearch

## Управление релизами Elastic Stack

```bash
# Масштабирование Elasticsearch
helm upgrade elasticsearch elastic/elasticsearch --set replicas=3

# Обновление конфигурации Kibana
helm upgrade kibana elastic/kibana --set service.type=NodePort

# Просмотр статуса всех компонентов
helm list -a
kubectl get pods,svc -l app=elasticsearch-master
kubectl get pods,svc -l app=kibana
```



## Создание своего Helm Chart

### 1. Создание структуры chart

```bash
# Создание нового chart
helm create myapp-chart

# Просмотр структуры созданного chart
tree myapp-chart/
```

Структура chart:
```
myapp-chart/
├── Chart.yaml          # Метаинформация о chart
├── values.yaml         # Значения по умолчанию
├── templates/          # Шаблоны Kubernetes манифестов
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── _helpers.tpl    # Вспомогательные шаблоны
└── charts/             # Зависимости (subcharts)
```

### 2. Пример простого Chart для Nginx

**Chart.yaml:**
```yaml
apiVersion: v2
name: my-nginx
description: A simple Nginx Helm chart
type: application
version: 0.1.0
appVersion: "1.19"
```

**values.yaml:**
```yaml
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.19"

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: ""
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix
```

**templates/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

**templates/service.yaml:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
  labels:
    app: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
      protocol: TCP
      name: http
  selector:
    app: {{ .Chart.Name }}
```

### 3. Тестирование и установка своего Chart

```bash
# Проверка синтаксиса шаблонов
helm lint myapp-chart

# Тестовый рендеринг шаблонов
helm template myapp-chart

# Установка в кластер
helm install my-release ./myapp-chart

# Установка с кастомными значениями
helm install my-release ./myapp-chart --set replicaCount=3

# Создание package
helm package myapp-chart
```

## Советы по работе с Helm

1. **Всегда используйте `--dry-run`** перед установкой для проверки
2. **Версионируйте свои charts** с помощью семантического версионирования
3. **Используйте `helm dependency update`** при изменении зависимостей
4. **Храните values файлы** в системе контроля версий
5. **Используйте `helm template`** для генерации манифестов в CI/CD





## 🔧 **Решения проблемы 403 Forbidden**

### **Решение 1: Использование ECK (Elastic Cloud on Kubernetes) - РЕКОМЕНДУЕМЫЙ**

ECK - это оператор для управления Elasticsearch в Kubernetes, он более современный и удобный:

```bash
# Добавляем репозиторий ECK
helm repo add eck https://helm.elastic.co
helm repo update

# Устанавливаем ECK operator
helm install eck-operator eck/eck-operator -n elastic-system --create-namespace

# Ждем пока оператор запустится
kubectl get pods -n elastic-system -w
```

**Создаем манифест для Elasticsearch:**
```yaml
# elasticsearch.yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 8.11.0
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 1Gi
              cpu: 500m
            limits:
              memory: 2Gi
              cpu: 1000m
```

```bash
# Применяем манифест
kubectl apply -f elasticsearch.yaml

# Проверяем статус
kubectl get elasticsearch
kubectl get pods -l elasticsearch.k8s.elastic.co/cluster-name=quickstart
```

### **Решение 2: Использование более старой версии Elasticsearch**

```bash
# Пробуем установить версию 7.x (может быть доступна без аутентификации)
helm install kn-elasticsearch elastic/elasticsearch --version 7.17.3
```


### **Решение 3: Ручное скачивание и установка**

```bash
# Скачиваем чарт вручную (если доступно)
wget https://github.com/elastic/helm-charts/releases/download/v8.5.1/elasticsearch-8.5.1.tgz

# Устанавливаем из локального файла
helm install kn-elasticsearch ./elasticsearch-8.5.1.tgz
```


## 🔍 **Проверка установки**

После установки любым методом:

```bash
# Проверяем поды
kubectl get pods

# Проверяем сервисы
kubectl get services

# Проверяем логи
kubectl logs deployment/kn-elasticsearch-elasticsearch

# Проверяем готовность
kubectl get elasticsearch  # для ECK
# или
helm status kn-elasticsearch  # для Bitnami
```
