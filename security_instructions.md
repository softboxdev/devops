# Задание: Настройка безопасности контейнера в Kubernetes

## Цель задания
Настроить политики безопасности для контейнеров в Kubernetes кластере, используя Security Context, Pod Security Standards и другие механизмы безопасности.

## Структура проекта
```
kubernetes-security/
├── namespace.yaml
├── service-account.yaml
├── pod-security-policy.yaml
├── security-context-pod.yaml
├── security-context-container.yaml
├── network-policy.yaml
├── psp-clusterrole.yaml
├── psp-rolebinding.yaml
└── README.md
```

## Подробное выполнение задания

### 1. Создание изолированного namespace

**Файл: `namespace.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security-demo
  labels:
    name: security-demo
    # Метка для автоматического применения Pod Security Standards
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```
**Комментарий:** Создаем отдельный namespace для изоляции наших security-настроек.

### 2. Создание Service Account с ограниченными правами

**Файл: `service-account.yaml`**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: restricted-sa
  namespace: security-demo
  # Аннотации для документации
  annotations:
    description: "Service account with restricted permissions"
```
**Комментарий:** Service Account обеспечивает идентификацию пода в кластере.

### 3. Security Context на уровне Pod

**Файл: `security-context-pod.yaml`**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-pod-demo
  namespace: security-demo
  labels:
    app: security-demo
spec:
  # Service Account который будет использоваться
  serviceAccountName: restricted-sa
  
  # Security Context на уровне Pod
  securityContext:
    runAsNonRoot: true        # Запрещает запуск от root пользователя
    runAsUser: 1000           # Запускать от пользователя с UID 1000
    runAsGroup: 3000          # Запускать от группы с GID 3000
    fsGroup: 4000             # GID для томов
    supplementalGroups: [5000, 6000]  # Дополнительные группы
    
    # Настройки SELinux/AppArmor
    seLinuxOptions:
      level: "s0:c123,c456"
    
    # Настройки seccomp профиля
    seccompProfile:
      type: RuntimeDefault     # Использовать дефолтный Runtime профиль
  
  containers:
  - name: nginx-container
    image: nginx:1.25
    ports:
    - containerPort: 80
```

### 4. Security Context на уровне контейнера

**Файл: `security-context-container.yaml`**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: container-security-demo
  namespace: security-demo
spec:
  serviceAccountName: restricted-sa
  
  containers:
  - name: secured-container
    image: nginx:1.25
    ports:
    - containerPort: 80
    
    # Security Context на уровне контейнера
    securityContext:
      allowPrivilegeEscalation: false    # Запрет эскалации привилегий
      privileged: false                  # Запрет privileged режима
      readOnlyRootFilesystem: true       # Только чтение для root FS
      runAsNonRoot: true                 # Запрет запуска от root
      runAsUser: 1000                    # UID пользователя
      runAsGroup: 1000                   # GID группы
      
      # Настройки capabilities
      capabilities:
        drop:                            # Удаляем опасные capabilities
          - ALL
        add:                             # Добавляем только необходимые
          - NET_BIND_SERVICE
      
      # Настройки AppArmor
      appArmorProfile: runtime/default
      
      # Настройки seccomp
      seccompProfile:
        type: RuntimeDefault
      
      # Ограничения ресурсов
      resources:
        requests:
          memory: "64Mi"
          cpu: "250m"
        limits:
          memory: "128Mi"
          cpu: "500m"
```

### 5. Network Policy для ограничения сетевого доступа

**Файл: `network-policy.yaml`**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: security-demo
spec:
  podSelector: {}              # Применяется ко всем pod в namespace
  policyTypes:
  - Ingress
  # Блокирует весь входящий трафик
  ingress: []                  # Пустой массив = запрет всего входящего трафика

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal-nginx
  namespace: security-demo
spec:
  podSelector:
    matchLabels:
      app: nginx
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: security-demo    # Разрешаем трафик только внутри namespace
    ports:
    - protocol: TCP
      port: 80
```

### 6. Pod Security Policy (если поддерживается кластером)

**Файл: `pod-security-policy.yaml`**
```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted-psp
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: 'runtime/default'
    apparmor.security.alpha.kubernetes.io/allowedProfileNames: 'runtime/default'
spec:
  privileged: false                          # Запрет privileged контейнеров
  allowPrivilegeEscalation: false           # Запрет эскалации привилегий
  requiredDropCapabilities:                 # Обязательное удаление capabilities
    - ALL
  
  # Настройки томов
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  
  # Настройки хоста
  hostNetwork: false                        # Запрет использования host network
  hostIPC: false                           # Запрет использования host IPC
  hostPID: false                           # Запрет использования host PID
  
  # Настройки пользователей и групп
  runAsUser:
    rule: 'MustRunAsNonRoot'               # Обязательный запуск не от root
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
      - min: 1
        max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
      - min: 1
        max: 65535
```

### 7. RBAC для Pod Security Policy

**Файл: `psp-clusterrole.yaml`**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: psp:restricted
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs:     ['use']
  resourceNames:
  - restricted-psp
```

**Файл: `psp-rolebinding.yaml`**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: psp:restricted:binding
  namespace: security-demo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psp:restricted
subjects:
- kind: ServiceAccount
  name: restricted-sa
  namespace: security-demo
```

## Пошаговое выполнение

### Шаг 1: Создание namespace
```bash
kubectl apply -f namespace.yaml
```

### Шаг 2: Создание Service Account
```bash
kubectl apply -f service-account.yaml
```

### Шаг 3: Применение Security Context
```bash
kubectl apply -f security-context-pod.yaml
kubectl apply -f security-context-container.yaml
```

### Шаг 4: Настройка Network Policies
```bash
kubectl apply -f network-policy.yaml
```

### Шаг 5: Проверка Pod Security Standards
```bash
# Проверка текущих стандартов безопасности
kubectl describe namespace security-demo
```

### Шаг 6: Валидация конфигурации
```bash
# Проверка созданных ресурсов
kubectl get pods,serviceaccounts,networkpolicies -n security-demo

# Проверка security context пода
kubectl describe pod security-context-pod-demo -n security-demo

# Проверка логиров
kubectl logs security-context-pod-demo -n security-demo
```

## Проверка безопасности

### Тест безопасности пода
```bash
# Попытка запуска privileged контейнера (должна завершиться ошибкой)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  namespace: security-demo
spec:
  containers:
  - name: test
    image: nginx
    securityContext:
      privileged: true
EOF
```

### Проверка network policy
```bash
# Создание тестового пода для проверки сетевой политики
kubectl run test-pod --image=nginx -n security-demo
kubectl exec -it test-pod -n security-demo -- curl http://security-context-pod-demo
```

## Ключевые концепции безопасности

### 1. Security Context
- **runAsNonRoot**: Запрещает запуск контейнера от пользователя root
- **runAsUser/runAsGroup**: Определяет UID/GID для запуска
- **fsGroup**: GID для монтируемых томов
- **capabilities**: Управление Linux capabilities

### 2. Pod Security Standards
- **Privileged**: Полный доступ к хосту
- **Baseline**: Минимальные ограничения
- **Restricted**: Строгие ограничения

### 3. Network Policies
- Контроль входящего/исходящего трафика
- Изоляция на уровне namespace
- Селекторы pod и namespace

### 4. Service Accounts
- Идентификация пода в кластере
- RBAC для контроля доступа
- Автоматическое создание токенов

## Дополнительные рекомендации

1. **Регулярное обновление образов** - используйте только проверенные и обновленные образы
2. **Scanning образов** - используйте инструменты для сканирования уязвимостей
3. **Audit logging** - настройте аудит безопасности кластера
4. **Resource limits** - всегда устанавливайте лимиты ресурсов
5. **Read-only root filesystem** - по возможности используйте read-only FS

Это задание демонстрирует комплексный подход к настройке безопасности контейнеров в Kubernetes, охватывая все основные аспекты: изоляцию, контроль доступа, ограничение привилегий и сетевую безопасность.