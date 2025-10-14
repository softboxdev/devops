# Policy Engine и Admission Controllers в Kubernetes

## Введение

### Что такое Admission Controllers?
**Admission Controllers** - это плагины в Kubernetes API сервере, которые перехватывают запросы к API серверу перед сохранением объектов в etcd. Они действуют как "привратники", проверяя и/или изменяя запросы.

### Что такое Policy Engine?
**Policy Engine** - это системы, которые позволяют определять и применять политики безопасности, соответствия и лучших практик в Kubernetes кластере.

## Подробное объяснение Admission Controllers

### Как работают Admission Controllers?

```
Клиент → API Server → Authentication → Authorization → Admission Control → etcd
                                                         ↓
                                            Mutating Webhooks → Validating Webhooks
```

### Типы Admission Controllers

#### 1. Встроенные (Built-in) Admission Controllers

**Примеры встроенных контроллеров:**
- **NamespaceLifecycle**: Запрещает создание объектов в несуществующих namespace
- **LimitRanger**: Устанавливает лимиты ресурсов по умолчанию
- **ResourceQuota**: Ограничивает потребление ресурсов
- **PodSecurity**: Реализует Pod Security Standards

#### 2. Dynamic Admission Controllers (Webhooks)

**Mutating Admission Webhooks:**
- Могут изменять объекты перед сохранением
- Выполняются перед validating webhooks
- Пример: автоматическое добавление labels, sidecar контейнеров

**Validating Admission Webhooks:**
- Проверяют объекты на соответствие политикам
- Не могут изменять объекты
- Пример: проверка security context, resource limits

### Конфигурация Admission Controllers

```bash
# Просмотр включенных admission controllers
kubectl get pods -n kube-system kube-apiserver-controlplane -o yaml | grep enable-admission-plugins

# Типичный набор admission controllers
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,PodSecurity
```

## Подробное объяснение Policy Engines

### Основные Policy Engines для Kubernetes

#### 1. Kyverno
**Особенности:**
- Политики как Kubernetes ресурсы (не требует внешних языков)
- Поддержка validate, mutate, generate действий
- Простая интеграция, не требует агентов

**Архитектура Kyverno:**
```
Kyverno Pod → Kubernetes API Server
    ↓
Admission Webhook → Policy Controller → Background Scanning
```

#### 2. OPA Gatekeeper
**Особенности:**
- Использует язык Rego для политик
- Более гибкий и мощный
- Constraint Framework (шаблоны + ограничения)

**Архитектура Gatekeeper:**
```
Gatekeeper Pod → Kubernetes API Server
    ↓
Constraint Templates → Constraints → Audit
```

#### 3. Pod Security Admission
**Встроенное решение:**
- Реализует Pod Security Standards
- Три уровня: privileged, baseline, restricted
- Настраивается через labels namespace

### Сравнение Policy Engines

| Характеристика | Kyverno | OPA Gatekeeper | Pod Security Admission |
|----------------|---------|----------------|------------------------|
| Сложность | Низкая | Высокая | Очень низкая |
| Гибкость | Средняя | Очень высокая | Низкая |
| Язык политик | YAML | Rego | Labels |
| Мутация | Да | Нет | Нет |
| Генерация | Да | Нет | Нет |

## Глубокое погружение в механизмы работы

### 1. Механизм Admission Webhooks

#### Webhook Configuration
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: "example.webhook.com"
webhooks:
- name: "example.webhook.com"
  clientConfig:
    service:
      name: "webhook-service"
      namespace: "webhook-namespace"
      path: "/validate"
    caBundle: "Ci0tLS0tQk...<CA_CERT>"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  failurePolicy: Fail
  sideEffects: None
  admissionReviewVersions: ["v1"]
```

#### Flow выполнения Webhook запроса

```
1. Пользователь отправляет kubectl apply -f pod.yaml
2. API Server аутентифицирует и авторизует запрос
3. API Server находит соответствующие webhook configurations
4. API Server отправляет AdmissionReview на webhook endpoint
5. Webhook сервер возвращает ответ (allow/deny)
6. API Server сохраняет или отвергает объект
```

### 2. Структура AdmissionReview запроса

```json
{
  "apiVersion": "admission.k8s.io/v1",
  "kind": "AdmissionReview",
  "request": {
    "uid": "12345-67890",
    "kind": {"group":"","version":"v1","kind":"Pod"},
    "resource": {"group":"","version":"v1","resource":"pods"},
    "name": "test-pod",
    "namespace": "default",
    "operation": "CREATE",
    "object": {
      "apiVersion": "v1",
      "kind": "Pod",
      "metadata": {"name": "test-pod", ...},
      "spec": { ... }
    },
    "oldObject": null
  }
}
```

### 3. Структура AdmissionReview ответа

```json
{
  "apiVersion": "admission.k8s.io/v1",
  "kind": "AdmissionReview",
  "response": {
    "uid": "12345-67890",
    "allowed": false,
    "status": {
      "code": 403,
      "message": "Privileged containers are not allowed"
    }
  }
}
```

## Практические примеры политик

### 1. Kyverno: Комплексная политика безопасности

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-security-baseline
spec:
  background: true
  validationFailureAction: enforce
  rules:
  - name: require-security-context
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Все Pod'ы должны иметь базовые настройки безопасности"
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: "RuntimeDefault"
          containers:
          - =(securityContext):
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                - "ALL"
  - name: require-resources
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Все контейнеры должны иметь limits и requests"
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
              requests:
                memory: "?*"
                cpu: "?*"
```

### 2. OPA Gatekeeper: Сложная бизнес-логика

```rego
# constrainttemplate.yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8suniqueingresshost
spec:
  crd:
    spec:
      names:
        kind: K8sUniqueIngressHost
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8suniqueingresshost
      
      violation[{"msg": msg}] {
        host := input.review.object.spec.rules[_].host
        other_ingress := data.kubernetes.ingresses[namespace][name]
        other_ingress.metadata.name != input.review.object.metadata.name
        other_ingress.spec.rules[_].host == host
        msg := sprintf("Host %v уже используется ingress %v/%v", [host, namespace, name])
      }
```

### 3. Mutating Webhook: Автоматическое улучшение безопасности

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-safe-defaults
spec:
  background: false
  rules:
  - name: add-security-context
    match:
      resources:
        kinds:
        - Pod
    mutate:
      patchStrategicMerge:
        spec:
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            seccompProfile:
              type: RuntimeDefault
          containers:
          - (name): "*"
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                - ALL
```

## Режимы работы и failure policies

### 1. Failure Policy Options

```yaml
# ValidatingWebhookConfiguration
failurePolicy: Fail
# или
failurePolicy: Ignore

# При Fail: если webhook недоступен, запрос блокируется
# При Ignore: если webhook недоступен, запрос пропускается
```

### 2. Validation Failure Actions

```yaml
# Kyverno
validationFailureAction: enforce  # Блокировать нарушающие запросы
validationFailureAction: audit    # Только логировать нарушения

# Gatekeeper
enforcementAction: deny           # Блокировать
enforcementAction: dryrun         # Только проверять
```

### 3. Side Effects

```yaml
sideEffects: None        # Webhook не имеет side effects
sideEffects: NoneOnDryRun # Нет side effects для dry-run запросов
sideEffects: Unknown     # Могут быть side effects (устаревшее)
```

## Best Practices и рекомендации

### 1. Безопасность Webhooks

```yaml
# Использование сертификатов
apiVersion: v1
kind: Secret
metadata:
  name: webhook-tls
  namespace: webhook-system
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

### 2. Производительность и надежность

```yaml
# Ограничение scope webhooks
namespaceSelector:
  matchExpressions:
  - key: environment
    operator: In
    values: [production]

objectSelector:
  matchLabels:
    security-tier: high

# Timeout настройки
timeoutSeconds: 5
```

### 3. Мониторинг и observability

```yaml
# Метрики для мониторинга
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: monitor-policy-violations
  annotations:
    policies.kyverno.io/category: Monitoring
spec:
  background: true
  rules:
  - name: log-policy-violations
    match:
      resources:
        kinds: [Pod, Deployment]
    validate:
      message: "Monitoring policy check"
```

## Реальные сценарии использования

### 1. Соответствие регуляторным требованиям

```yaml
# PCI-DSS compliance policy
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pci-dss-compliance
spec:
  rules:
  - name: require-no-privileged
    match:
      resources:
        kinds: [Pod]
    validate:
      message: "PCI-DSS: Privileged containers запрещены"
      pattern:
        spec:
          containers:
          - securityContext:
              =(privileged): false
```

### 2. Multi-tenant безопасность

```yaml
# Изоляция tenant'ов
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: tenant-isolation
spec:
  rules:
  - name: block-cross-tenant-access
    match:
      resources:
        kinds: [NetworkPolicy]
    validate:
      message: "NetworkPolicy не может разрешать cross-tenant доступ"
      deny:
        conditions:
        - key: "{{ request.object.spec.ingress[].from[].namespaceSelector.matchLabels.tenant }}"
          operator: NotEquals
          value: "{{ request.namespaceObject.metadata.labels.tenant }}"
```

### 3. Cost Optimization

```yaml
# Контроль ресурсов
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: cost-control
spec:
  rules:
  - name: limit-resource-requests
    match:
      resources:
        kinds: [Pod]
    validate:
      message: "CPU request не может превышать 2 ядер"
      pattern:
        spec:
          containers:
          - resources:
              requests:
                cpu: "<=2"
```

## Отладка и troubleshooting

### 1. Проверка webhook конфигураций

```bash
# Просмотр webhook configurations
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations

# Детальная информация
kubectl describe validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg

# Проверка endpoints
kubectl get endpoints -n kyverno
```

### 2. Анализ логов

```bash
# Логи API server
kubectl logs -n kube-system kube-apiserver-controlplane

# Логи Kyverno
kubectl logs -n kyverno -l app=kyverno

# Логи Gatekeeper
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

### 3. Тестирование политик

```bash
# Kyverno CLI тестирование
kyverno apply policy.yaml --resource pod.yaml

# Gatekeeper testing
kubectl apply -f constraint.yaml --dry-run=server

# Manual webhook testing
kubectl create -f test-pod.yaml --dry-run=server -o yaml
```

## Заключение

### Ключевые преимущества

1. **Единая точка контроля**: Централизованное управление политиками
2. **Проактивная безопасность**: Предотвращение нарушений до их возникновения
3. **Автоматизация**: Устранение ручных проверок и человеческого фактора
4. **Соответствие**: Документирование и обеспечение compliance требований

### Рекомендуемый подход

1. Начните с **Pod Security Admission** для базовой безопасности
2. Добавьте **Kyverno** для простых политик и мутаций
3. Используйте **OPA Gatekeeper** для сложной бизнес-логики
4. Реализуйте **custom webhooks** для специфических требований

Policy Engines и Admission Controllers предоставляют мощный механизм для обеспечения безопасности, соответствия и лучших практик в Kubernetes, превращая кластер из просто orchestrator'а в безопасную и управляемую платформу.