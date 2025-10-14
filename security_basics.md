# Введение в безопасность проекта на Kubernetes

## 1. Основные концепции безопасности Kubernetes

### 1.1 Модель безопасности "4C"
Безопасность в Kubernetes строится по принципу "4C" (Cloud, Cluster, Container, Code):

- **Cloud** - инфраструктурная безопасность
- **Cluster** - безопасность самого кластера Kubernetes
- **Container** - безопасность контейнеров и образов
- **Code** - безопасность приложения и зависимостей

### 1.2 Shared Responsibility Model
В Kubernetes действует модель разделенной ответственности:

**Ответственность провайдера:**
- Безопасность инфраструктуры
- Безопасность control plane
- Обновления кластера

**Ответственность пользователя:**
- Конфигурация рабочих нагрузок
- Управление секретами
- Сетевая политика
- Обновления приложений

## 2. Аутентификация и авторизация

### 2.1 Аутентификация (Authentication)
```yaml
# Пример ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: production
```

**Методы аутентификации:**
- Service Account Tokens
- X.509 Client Certificates
- OpenID Connect Tokens
- Authenticating Proxy

### 2.2 Авторизация (Authorization) с RBAC
```yaml
# Пример Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

```yaml
# Пример RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: default
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

## 3. Безопасность Pod'ов

### 3.1 Security Context
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    runAsNonRoot: true
  containers:
  - name: sec-ctx-demo
    image: busybox
    command: ["sh", "-c", "sleep 1h"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
```

### 3.2 Pod Security Standards
- **Privileged**: Неограниченный доступ (не рекомендуется)
- **Baseline**: Минимальные ограничения
- **Restricted**: Строгие ограничения

## 4. Сетевая безопасность

### 4.1 Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 80
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

## 5. Управление секретами

### 5.1 Kubernetes Secrets
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  username: dXNlcm5hbWU=  # base64
  password: cGFzc3dvcmQ=  # base64
```

### 5.2 External Secret Management
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager

## 6. Безопасность образов контейнеров

### 6.1 Best Practices
- Использование минимальных базовых образов (Alpine, Distroless)
- Регулярное обновление образов
- Сканирование на уязвимости
- Подписывание образов (Cosign)

```dockerfile
# Пример безопасного Dockerfile
FROM alpine:3.18
RUN addgroup -S app && adduser -S app -G app
USER app
COPY --chown=app:app ./app /app
WORKDIR /app
CMD ["./app"]
```

## 7. Мониторинг и аудит

### 7.1 Kubernetes Audit Logging
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  namespaces: ["kube-system"]
  verbs: ["delete"]
  resources:
  - group: ""
    resources: ["secrets"]
```

### 7.2 Security Monitoring
- Falco для обнаружения аномалий
- kube-bench для проверки соответствия CIS Benchmark
- kube-hunter для тестирования на проникновение

## 8. Pod Security Admission

### 8.1 Namespace Labels
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## 9. Service Mesh Security

### 9.1 Istio Security Features
- mTLS между сервисами
- Authorization policies
- Traffic encryption
- Identity management

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

## 10. Безопасность узлов (Nodes)

### 10.1 Hardening узлов
- Регулярное обновление ОС
- Отключение ненужных служб
- Использование AppArmor/SELinux
- Ограничение доступа к Docker socket

## 11. Инструменты безопасности

### 11.1 Статический анализ
- **kube-score**: Анализ манифестов Kubernetes
- **checkov**: Анализ инфраструктуры как код
- **trivy**: Сканирование образов на уязвимости

### 11.2 Runtime Security
- **Falco**: Runtime security monitoring
- **Aqua Security**: Комплексная защита
- **Sysdig Secure**: Мониторинг и защита

## 12. Процесс внедрения безопасности

### 12.1 Поэтапный подход
1. **Аудит**: Оценка текущего состояния
2. **Базовая защита**: RBAC, Network Policies
3. **Усиление защиты**: Pod Security, Secrets management
4. **Мониторинг**: Audit logging, runtime protection
5. **Автоматизация**: Security as Code, CI/CD pipeline checks

### 12.2 CI/CD Pipeline Security
```yaml
# Пример GitHub Actions pipeline
name: Security Scan
on: [push]
jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Run kube-score
      uses: zegl/kube-score-action@v1
    - name: Scan image
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'my-app:latest'
        format: 'sarif'
        output: 'trivy-results.sarif'
```

## 13. Соответствие стандартам

### 13.1 CIS Kubernetes Benchmark
- Регулярные проверки с kube-bench
- Автоматизация compliance checks
- Документирование исключений

### 13.2 GDPR, HIPAA, SOC 2
- Шифрование данных в rest и transit
- Контроль доступа
- Аудит и логирование

## Заключение

Безопасность в Kubernetes — это непрерывный процесс, требующий комплексного подхода. Начните с базовых мер (RBAC, Network Policies), постепенно внедряйте более сложные механизмы и автоматизируйте процессы безопасности. Регулярно проводите аудиты и тестирования, чтобы обеспечить постоянный уровень защиты ваших приложений и данных.