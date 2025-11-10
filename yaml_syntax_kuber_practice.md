# Практическая работа: Создание YAML манифестов для Kubernetes

## Цель работы
Научиться самостоятельно писать базовые YAML манифесты для развертывания приложения в Kubernetes.

## Предварительные требования
- Установленный kubectl
- Доступ к Kubernetes кластеру (можно использовать Minikube или kind)

---

## Задание 1: Создание простого Pod

**Задача:** Создать Pod с веб-сервером nginx

### Подсказки:
<details>
<summary>Подсказка 1 (если совсем сложно)</summary>

Вам понадобятся следующие основные секции:
- `apiVersion`
- `kind` 
- `metadata` с `name`
- `spec` с `containers`

</details>

<details>
<summary>Подсказка 2 (структура)</summary>

```yaml
apiVersion: 
kind: 
metadata:
  name: 
spec:
  containers:
  - name: 
    image: 
    ports:
    - containerPort: 
```

</details>

<details>
<summary>Подсказка 3 (значения)</summary>

- apiVersion для Pod: `v1`
- kind: `Pod`
- имя Pod: `my-nginx-pod`
- имя контейнера: `nginx-container`
- образ: `nginx:1.19`
- порт: `80`

</details>

**Проверка решения:**
```bash
kubectl apply -f your-pod.yaml
kubectl get pods
kubectl describe pod my-nginx-pod
```

---

## Задание 2: Создание Deployment

**Задача:** Создать Deployment для того же nginx, который поддерживает 3 реплики

### Подсказки:
<details>
<summary>Подсказка 1 (структура)</summary>

Deployment имеет более сложную структуру чем Pod. Нужно определить:
- селектор для поиска Pod'ов
- шаблон Pod'а
- количество реплик

</details>

<details>
<summary>Подсказка 2 (критически важная связь)</summary>

Помните, что `selector.matchLabels` должен совпадать с `template.metadata.labels`

</details>

<details>
<summary>Подсказка 3 (значения)</summary>

- apiVersion: `apps/v1`
- kind: `Deployment`
- имя: `my-nginx-deployment`
- реплики: `3`
- лейбл для селектора: `app: nginx-app`
- контейнер такой же как в задании 1

</details>

**Проверка решения:**
```bash
kubectl apply -f your-deployment.yaml
kubectl get deployment
kubectl get pods -l app=nginx-app
```

---

## Задание 3: Создание Service

**Задача:** Создать Service для доступа к Pod'ам из Deployment

### Подсказки:
<details>
<summary>Подсказка 1 (назначение Service)</summary>

Service обеспечивает стабильный доступ к Pod'ам. Селектор Service должен совпадать с лейблами Pod'ов.

</details>

<details>
<summary>Подсказка 2 (структура)</summary>

```yaml
apiVersion: v1
kind: Service
metadata:
  name: 
spec:
  selector: 
    app: 
  ports:
  - protocol: TCP
    port: 
    targetPort: 
  type: 
```

</details>

<details>
<summary>Подсказка 3 (значения)</summary>

- имя Service: `nginx-service`
- селектор: `app: nginx-app` (такой же как в Deployment)
- port: `80`
- targetPort: `80` (порт контейнера)
- type: `ClusterIP`

</details>

**Проверка решения:**
```bash
kubectl apply -f your-service.yaml
kubectl get service
kubectl describe service nginx-service
```

---

## Задание 4: Комплексное задание (самостоятельно)

**Задача:** Создать Deployment и Service для приложения Redis

**Требования:**
- Deployment с именем `redis-deployment`
- 2 реплики Pod'ов
- Лейбл `app: redis-cache`
- Контейнер с именем `redis-container`, образом `redis:7-alpine`
- Порт контейнера: `6379`
- Service с именем `redis-service`
- Type: ClusterIP
- Порт service: `6379`, targetPort: `6379`

**Проверка:**
```bash
kubectl get all -l app=redis-cache
```

---

## Задание 5: Добавление конфигурации

**Задача:** Модифицировать Deployment nginx чтобы добавить:
- Переменные окружения
- Лимиты ресурсов

### Подсказки:
<details>
<summary>Что добавить в контейнер</summary>

```yaml
env:
- name: NGINX_ENV
  value: "production"
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

</details>

---

## Бонусное задание для продвинутых

**Задача:** Создать ConfigMap и использовать ее в Deployment

1. Создать ConfigMap с настройками nginx:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        location / {
            return 200 "Hello from ConfigMap!";
        }
    }
```

2. Модифицировать Deployment nginx чтобы смонтировать этот ConfigMap как volume

Подсказка: ищите в документации `volumes` и `volumeMounts`

---

## Проверка всей работы

После выполнения всех заданий выполните:
```bash
# Посмотреть все созданные ресурсы
kubectl get all

# Удалить все созданные ресурсы
kubectl delete deployment,service,pod,configmap --all
```

## Критерии успешного выполнения

- [ ] Pod nginx создается и переходит в статус Running
- [ ] Deployment создает 3 реплики Pod'ов
- [ ] Service находит Pod'ы по лейблам
- [ ] Redis Deployment и Service работают корректно
- [ ] Конфигурация с переменными окружения и лимитами применена
- [ ] Бонус: ConfigMap смонтирован в Pod

## Что должно получиться в итоге

У вас должно быть 4-5 YAML файлов:
1. `nginx-pod.yaml`
2. `nginx-deployment.yaml` 
3. `nginx-service.yaml`
4. `redis-deployment-service.yaml`
5. `nginx-with-config.yaml` (бонус)

Поздравляю! Вы освоили основы создания YAML манифестов для Kubernetes! 🎉