# Авторизация, аутентификация и аккаунтинг в Kubernetes: Подробное руководство

## 1. Введение в AAA (Authentication, Authorization, Accounting)

### 1.1 Концепция "3A" в Kubernetes

**Аналогия с охраняемым зданием:**
- 🆔 **Аутентификация** = Проверка пропуска ("Кто вы?")
- 🔐 **Авторизация** = Проверка прав доступа ("Куда вам можно?")
- 📋 **Аккаунтинг** = Журнал посещений ("Кто, куда и когда зашел?")

### 1.2 Поток запроса в Kubernetes

```
Пользователь/Приложение
        ↓
[Аутентификация] → Проверка личности
        ↓
[Авторизация] → Проверка прав доступа
        ↓  
[Admission Control] → Дополнительные проверки
        ↓
[Аккаунтинг] → Логирование действий
        ↓
API Server → Выполнение операции
```

## 2. Аутентификация (Authentication)

### 2.1 Что такое аутентификация?

**Аутентификация** - процесс проверки подлинности пользователя или сервиса.

### 2.2 Методы аутентификации

Kubernetes поддерживает несколько методов аутентификации:

#### 2.2.1 X.509 Client Certificates
```bash
# Просмотр текущего контекста
kubectl config view

# Пример конфигурации с клиентским сертификатом
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
    server: https://api.k8s-cluster.example.com
  name: production
contexts:
- context:
    cluster: production
    user: admin-user
  name: production-context
current-context: production-context
users:
- name: admin-user
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t...
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQ...
```

#### 2.2.2 Service Account Tokens
```yaml
# Создание Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: production
automountServiceAccountToken: false  # Рекомендуется для безопасности

---
# Pod, использующий Service Account
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: production
spec:
  serviceAccountName: my-app-sa
  containers:
  - name: app
    image: my-app:latest
```

#### 2.2.3 OpenID Connect (OIDC)
```yaml
# Запуск API Server с OIDC аутентификацией
kube-apiserver \
  --oidc-issuer-url=https://accounts.google.com \
  --oidc-client-id=kubernetes-client-id \
  --oidc-username-claim=email \
  --oidc-groups-claim=groups
```

#### 2.2.4 Authenticating Proxy
```yaml
# Настройка API Server для работы с аутентифицирующим прокси
kube-apiserver \
  --requestheader-username-headers=X-Remote-User \
  --requestheader-group-headers=X-Remote-Group \
  --requestheader-extra-headers-prefix=X-Remote-Extra- \
  --requestheader-client-ca-file=/path/to/ca.crt \
  --requestheader-allowed-names=auth-proxy
```

### 2.3 Service Accounts в деталях

#### 2.3.1 Создание и использование Service Account
```bash
# Создание Service Account
kubectl create serviceaccount my-app-sa -n production

# Просмотр созданного Service Account
kubectl get serviceaccount my-app-sa -n production -o yaml

# Создание Secret для Service Account (если нужно)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: my-app-sa-token
  namespace: production
  annotations:
    kubernetes.io/service-account.name: my-app-sa
type: kubernetes.io/service-account-token
EOF
```

#### 2.3.2 Использование в Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: production
spec:
  serviceAccountName: my-app-sa
  automountServiceAccountToken: true  # По умолчанию true
  containers:
  - name: app
    image: my-app:latest
    env:
    - name: KUBERNETES_SERVICE_HOST
      value: "kubernetes.default.svc"
```

## 3. Авторизация (Authorization)

### 3.1 Что такое авторизация?

**Авторизация** - процесс проверки прав доступа аутентифицированного пользователя/сервиса к выполнению конкретных операций.

### 3.2 Модули авторизации

Kubernetes поддерживает несколько модулей авторизации:

#### 3.2.1 RBAC (Role-Based Access Control) - Рекомендуется
```yaml
# Role - права в пределах namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: production
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

---
# ClusterRole - права во всем кластере  
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-viewer
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]

---
# RoleBinding - связь Role с субъектом
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: production
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

#### 3.2.2 ABAC (Attribute-Based Access Control)
```json
{
  "apiVersion": "abac.authorization.kubernetes.io/v1beta1",
  "kind": "Policy",
  "spec": {
    "user": "alice",
    "namespace": "production",
    "resource": "pods",
    "readonly": true
  }
}
```

#### 3.2.3 Webhook Authorization
```yaml
# Настройка API Server для Webhook авторизации
kube-apiserver \
  --authorization-mode=Webhook \
  --authorization-webhook-config-file=/path/to/webhook-config.yaml
```

### 3.3 Детальное руководство по RBAC

#### 3.3.1 Основные компоненты RBAC

**Role & ClusterRole:**
```yaml
# Role с множественными правами
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: deployment-manager
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

# ClusterRole для просмотра нод
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-node-viewer
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
```

**RoleBinding & ClusterRoleBinding:**
```yaml
# RoleBinding для пользователя
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer-binding
  namespace: default
subjects:
- kind: User
  name: deployer-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: deployment-manager
  apiGroup: rbac.authorization.k8s.io

# ClusterRoleBinding для группы
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-viewers-binding
subjects:
- kind: Group
  name: "cluster-viewers"
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-node-viewer
  apiGroup: rbac.authorization.k8s.io
```

#### 3.3.2 Практические примеры RBAC

**Разработчик в namespace:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: development
  name: developer
rules:
- apiGroups: ["", "apps", "batch"]
  resources: ["*"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get"]
```

**Оператор базы данных:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: database-operator
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["statefulsets"]
  verbs: ["*"]
```

### 3.4 Проверка прав доступа

```bash
# Проверка может ли пользователь выполнить действие
kubectl auth can-i get pods --as=developer-user
kubectl auth can-i create deployments --namespace=production --as=ci-cd-service

# Проверка прав для текущего пользователя
kubectl auth can-i list nodes
kubectl auth can-i delete pods --namespace=kube-system

# Просмотр всех доступных прав
kubectl auth can-i --list
```

## 4. Аккаунтинг (Accounting) / Аудит (Auditing)

### 4.1 Что такое аккаунтинг?

**Аккаунтинг** - процесс логирования и отслеживания всех действий в кластере для последующего анализа и соответствия требованиям.

### 4.2 Настройка аудита в Kubernetes

#### 4.2.1 Политика аудита
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  namespaces: ["kube-system"]
  verbs: ["delete", "create", "update"]
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  
- level: RequestResponse
  namespaces: ["production"]
  users: ["admin", "system:serviceaccount:kube-system:cluster-admin"]
  resources:
  - group: ""
    resources: ["secrets"]
  
- level: Request
  resources:
  - group: ""
    resources: ["pods", "services"]
  
- level: None
  userGroups: ["system:authenticated"]
  nonResourceURLs:
  - "/healthz"
  - "/version"
```

#### 4.2.2 Запуск API Server с аудитом
```bash
kube-apiserver \
  --audit-policy-file=/etc/kubernetes/audit-policy.yaml \
  --audit-log-path=/var/log/kubernetes/audit.log \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=10 \
  --audit-log-maxsize=100
```

### 4.3 Анализ аудит-логов

#### 4.3.1 Просмотр логов
```bash
# Просмотр аудит-логов
tail -f /var/log/kubernetes/audit.log | jq .

# Поиск конкретных операций
grep "delete.*secret" /var/log/kubernetes/audit.log

# Анализ с помощью jq
cat audit.log | jq '. | select(.verb == "delete") | .user.username'
```

#### 4.3.2 Пример записи аудит-лога
```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "RequestResponse",
  "auditID": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/production/secrets/db-password",
  "verb": "get",
  "user": {
    "username": "system:serviceaccount:production:my-app-sa",
    "uid": "abcd1234-5678-90ef-ghij-klmnopqrstuv",
    "groups": ["system:serviceaccounts", "system:serviceaccounts:production"]
  },
  "sourceIPs": ["10.0.1.23"],
  "userAgent": "my-app/1.0",
  "objectRef": {
    "resource": "secrets",
    "namespace": "production",
    "name": "db-password",
    "apiVersion": "v1"
  },
  "responseStatus": {
    "metadata": {},
    "code": 200
  },
  "requestReceivedTimestamp": "2023-10-01T12:00:00.000000Z",
  "stageTimestamp": "2023-10-01T12:00:00.100000Z",
  "annotations": {
    "authorization.k8s.io/decision": "allow",
    "authorization.k8s.io/reason": "RBAC: allowed by RoleBinding \"read-secrets/production\""
  }
}
```

## 5. Интегрированный пример: Полная настройка безопасности

### 5.1 Создание безопасного окружения

```bash
# Создание namespace
kubectl create namespace secure-app

# Создание Service Account
kubectl create serviceaccount app-sa -n secure-app

# Создание Role и RoleBinding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: secure-app
  name: app-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-binding
  namespace: secure-app
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: secure-app
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

### 5.2 Deployment с использованием Service Account
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: secure-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      serviceAccountName: app-sa
      automountServiceAccountToken: true
      containers:
      - name: app
        image: my-secure-app:latest
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
        env:
        - name: KUBERNETES_SERVICE_HOST
          value: "kubernetes.default.svc"
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
```

## 6. Best Practices безопасности

### 6.1 Принцип минимальных привилегий

```yaml
# ПЛОХО: Слишком широкие права
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]

# ХОРОШО: Только необходимые права
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
```

### 6.2 Регулярный аудит прав доступа

```bash
# Проверка всех Role и ClusterRole
kubectl get roles --all-namespaces
kubectl get clusterroles

# Анализ привязок
kubectl get rolebindings --all-namespaces -o wide
kubectl get clusterrolebindings -o wide

# Проверка Service Accounts
kubectl get serviceaccounts --all-namespaces
```

### 6.3 Мониторинг подозрительной активности

```bash
# Поиск операций с секретами
cat audit.log | jq 'select(.objectRef.resource == "secrets")'

# Поиск операций от service accounts
cat audit.log | jq 'select(.user.username | startswith("system:serviceaccount"))'

# Мониторинг failed auth attempts
grep "AnonymousAuth" /var/log/kube-apiserver.log
```

## 7. Инструменты для управления безопасностью

### 7.1 kube-bench (CIS Benchmark)
```bash
# Проверка безопасности кластера
docker run --rm --pid=host -v /etc:/etc:ro -v /var:/var:ro \
  aquasec/kube-bench:latest run
```

### 7.2 rbac-lookup
```bash
# Установка
kubectl krew install rbac-lookup

# Поиск прав пользователей
kubectl rbac-lookup alice
kubectl rbac-lookup system:serviceaccount:production:app-sa
```

### 7.3 kubeaudit
```bash
# Аудит безопасности
kubeaudit all -f deployment.yaml
kubeaudit autofix -f deployment.yaml
```

## 8. Решение проблем

### 8.1 Ошибки аутентификации
```bash
# Проверка текущего контекста
kubectl config current-context
kubectl config view

# Проверка сертификатов
openssl x509 -in /path/to/client.crt -text -noout
```

### 8.2 Ошибки авторизации
```bash
# Проверка прав
kubectl auth can-i create pods --namespace=production

# Просмотр RoleBindings
kubectl describe rolebinding my-binding -n production

# Проверка логики RBAC
kubectl get role,rolebinding,clusterrole,clusterrolebinding --all-namespaces
```

### 8.3 Проблемы с Service Accounts
```bash
# Проверка Service Account
kubectl get serviceaccount my-sa -o yaml

# Проверка секретов
kubectl get secrets --namespace=production

# Проверка mounted token в Pod
kubectl exec -it my-pod -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

## Заключение

Эффективная система AAA в Kubernetes требует:

- ✅ **Надежной аутентификации** (Service Accounts, X.509, OIDC)
- ✅ **Гранулярной авторизации** (RBAC с минимальными привилегиями)  
- ✅ **Полного аудита** всех операций в кластере
- ✅ **Регулярного пересмотра** прав доступа
- ✅ **Мониторинга** подозрительной активности

Правильно настроенная система AAA - основа безопасности Kubernetes кластера! 🔒