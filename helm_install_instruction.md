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

### 1. Добавление репозиториев

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

## Практические упражнения

### Упражнение 1: Установка и настройка WordPress

```bash
# Поиск WordPress chart
helm search repo wordpress

# Просмотр значений
helm show values bitnami/wordpress

# Установка WordPress с внешней базой данных
helm install my-wordpress bitnami/wordpress \
  --set mariadb.enabled=false \
  --set externalDatabase.host=mysql-server \
  --set service.type=LoadBalancer
```

### Упражнение 2: Создание Chart для простого веб-приложения

1. Создайте chart для простого веб-приложения
2. Добавьте ConfigMap для конфигурации
3. Добавьте Secret для чувствительных данных
4. Настройте Ingress для внешнего доступа

### Упражнение 3: Работа с зависимостями

Создайте `Chart.yaml` с зависимостями:

```yaml
apiVersion: v2
name: my-webapp
dependencies:
  - name: redis
    version: "17.0.0"
    repository: "https://charts.bitnami.com/bitnami"
  - name: postgresql
    version: "12.0.0"
    repository: "https://charts.bitnami.com/bitnami"
```

```bash
# Скачивание зависимостей
helm dependency update

# Установка с зависимостями
helm install my-app .
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
```

## Советы по работе с Helm

1. **Всегда используйте `--dry-run`** перед установкой для проверки
2. **Версионируйте свои charts** с помощью семантического версионирования
3. **Используйте `helm dependency update`** при изменении зависимостей
4. **Храните values файлы** в системе контроля версий
5. **Используйте `helm template`** для генерации манифестов в CI/CD

