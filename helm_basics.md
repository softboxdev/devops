# **Введение в Helm: Полное руководство для начинающих**

## **🎯 Что такое Helm?**

**Helm** — это менеджер пакетов для Kubernetes, который упрощает установку и управление приложениями.

**Простая аналогия:**
- **Kubernetes** — как операционная система
- **Helm** — как менеджер пакетов (apt, yum, brew)
- **Charts** — как пакеты приложений (.deb, .rpm)

---

## **📚 Архитектура Helm**

### **Helm v2 (Устаревшая версия)**

```bash
# Архитектура Helm v2:
Пользователь → Helm Client → Tiller (в кластере) → Kubernetes API
```

**Компоненты Helm v2:**

1. **Helm Client** - CLI инструмент на вашей машине
2. **Tiller** - серверный компонент внутри кластера
   - Управлял установкой релизов
   - Имел широкие права в кластере
   - Потенциальная уязвимость безопасности

**Проблемы Tiller:**
- Требовал права cluster-admin
- Одна точка отказа
- Проблемы безопасности

### **Helm v3 (Современная версия)**

```bash
# Архитектура Helm v3:
Пользователь → Helm Client → Kubernetes API
```

**Изменения в Helm v3:**
- ✅ **Убран Tiller** - больше нет серверного компонента
- ✅ **Улучшена безопасность** - использует права пользователя kubectl
- ✅ **Проще архитектура** - только CLI инструмент
- ✅ **Лучшие возможности** - библиотечные charts, улучшенная работа с зависимостями

---

## **📦 Основные концепции Helm**

### **1. Charts (Чарты)**

**Chart** — это пакет Helm, содержащий все ресурсы для запуска приложения в Kubernetes.

**Структура Chart:**
```
my-app-chart/
├── Chart.yaml          # Метаинформация о chart
├── values.yaml         # Значения по умолчанию
├── charts/             # Зависимости (subcharts)
├── templates/          # Шаблоны Kubernetes манифестов
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
└── README.md
```

**Пример Chart.yaml:**
```yaml
apiVersion: v2
name: my-web-app
description: A simple web application
type: application
version: 1.0.0
appVersion: "2.1.0"
```

### **2. Templates (Шаблоны)**

**Templates** — это файлы YAML с дополнительными возможностями подстановки значений.

**Пример template/deployment.yaml:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-deployment
  # ↑ Подстановка имени релиза
spec:
  replicas: {{ .Values.replicaCount }}
  # ↑ Подстановка значения из values.yaml
  selector:
    matchLabels:
      app: {{ .Values.app.name }}
  template:
    metadata:
      labels:
        app: {{ .Values.app.name }}
    spec:
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        # ↑ Подстановка имени образа и тега
        ports:
        - containerPort: {{ .Values.service.port }}
```

### **3. Releases (Релизы)**

**Release** — это конкретный экземпляр chart, установленный в кластере.

**Пример:**
- Chart: `nginx` (пакет)
- Release: `my-website` (установленный экземпляр)
- Release: `my-blog` (другой установленный экземпляр того же chart)

---

## **🏪 Helm репозитории**

### **Что такое Helm репозиторий?**

**Helm Repository** — это место, где хранятся и распространяются charts (как репозиторий пакетов).

### **Типы репозиториев:**

1. **Публичные репозитории** - Bitnami, Elastic, Jetstack
2. **Приватные репозитории** - ваш собственный
3. **Локальные charts** - разработанные вами

### **Работа с репозиториями:**

```bash
# Добавить публичный репозиторий
helm repo add bitnami https://charts.bitnami.com/bitnami

# Добавить приватный репозиторий
helm repo add my-company https://charts.my-company.com/

# Обновить информацию о репозиториях
helm repo update

# Посмотреть список репозиториев
helm repo list

# Поиск charts в репозиториях
helm search repo nginx

# Установить chart из репозитория
helm install my-nginx bitnami/nginx

# Удалить репозиторий
helm repo remove bitnami
```

---

## **🛠 Практическое использование Helm**

### **Базовые команды Helm:**

```bash
# Создать новый chart
helm create my-app

# Установить chart
helm install my-release ./my-app

# Установить с кастомными значениями
helm install my-release ./my-app -f values-prod.yaml

# Обновить установленный release
helm upgrade my-release ./my-app

# Посмотреть установленные releases
helm list

# Удалить release
helm uninstall my-release

# Посмотреть сгенерированные манифесты (без установки)
helm template my-release ./my-app

# Проверить chart на ошибки
helm lint ./my-app
```

### **Пример полного workflow:**

```bash
# 1. Добавить репозиторий
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. Поиск нужного chart
helm search repo mysql

# 3. Скачать chart для изучения
helm pull bitnami/mysql --untar

# 4. Установка с кастомными значениями
helm install my-database bitnami/mysql \
  --set auth.rootPassword=secretpassword \
  --set auth.database=myapp

# 5. Проверить установку
helm list
kubectl get pods

# 6. Обновить конфигурацию
helm upgrade my-database bitnami/mysql \
  --set auth.database=mynewapp

# 7. Удалить когда не нужно
helm uninstall my-database
```

---

## **📋 Сравнение: Ручная установка vs Helm**

### **Без Helm (ручная установка):**
```bash
# Создать несколько файлов
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Для обновления - редактировать все файлы
# Нет версионирования
# Сложно управлять зависимостями
```

### **С Helm:**
```bash
# Одна команда для установки
helm install my-app ./my-chart

# Легкое обновление
helm upgrade my-app ./my-chart

# Версионирование и история
helm history my-app

# Простое удаление
helm uninstall my-app
```

---

## **🎯 Преимущества Helm**

### **✅ Для разработчиков:**
- **Шаблонизация** - избежание дублирования кода
- **Параметризация** - разные окружения через values
- **Повторное использование** - один chart для dev/stage/prod

### **✅ Для операторов:**
- **Простота установки** - одна команда для сложных приложений
- **Управление версиями** - отслеживание изменений
- **Откат изменений** - `helm rollback`
- **Зависимости** - автоматическая установка связанных компонентов

### **✅ Для организации:**
- **Стандартизация** - единый способ установки приложений
- **Каталог charts** - внутренний репозиторий
- **CI/CD интеграция** - автоматизация развертывания

---

## **🚀 Практические упражнения**

### **Упражнение 1: Установка готового chart**
```bash
# Установите WordPress с помощью Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install my-wordpress bitnami/wordpress
# Или другой
helm repo add stable https://charts.helm.sh/stable
helm repo update
helm search repo nginx

# Проверьте что установилось
helm list
kubectl get pods
```

### **Упражнение 2: Создание простого chart**
```bash
# Создайте свой первый chart
helm create my-first-chart

# Изучите структуру
cd my-first-chart
ls -la

# Установите его
helm install test ./my-first-chart
```

### **Упражнение 3: Работа с values**
```bash
# Добавить репозиторий NGINX
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

# Посмотреть значения
helm show values nginx-stable/nginx-ingress

# Установить
helm install my-nginx nginx-stable/nginx-ingress \
  --set controller.service.type=LoadBalancer \
  --set controller.replicaCount=3
```

---

## **📊 Шпаргалка по основным командам**

```bash
# Репозитории
helm repo add [name] [url]      # Добавить репозиторий
helm repo update               # Обновить список charts
helm repo list                 # Показать репозитории

# Установка и управление
helm install [name] [chart]    # Установить chart
helm list                      # Показать установленные releases
helm upgrade [release] [chart] # Обновить release
helm uninstall [release]       # Удалить release
helm history [release]         # Показать историю
helm rollback [release] [rev]  # Откатить версию

# Разработка
helm create [name]             # Создать новый chart
helm lint [chart]              # Проверить chart на ошибки
helm template [chart]          # Показать сгенерированные манифесты
helm package [chart]           # Создать .tgz пакет
```

**Helm делает управление Kubernetes приложениями таким же простым, как установка пакетов в Linux! 🎉**