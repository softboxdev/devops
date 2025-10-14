# Задание: Настройка Policy Engine и Admission Controllers в Kubernetes

## Цель задания
Настроить и использовать политики безопасности через Admission Controllers и Policy Engines для принудительного применения стандартов безопасности в кластере Kubernetes.

## Структура проекта
```
policy-engine-demo/
├── 00-namespace.yaml
├── 01-kyverno-install.yaml
├── 02-kyverno-policies/
│   ├── require-labels.yaml
│   ├── disallow-privileged.yaml
│   ├── require-resource-limits.yaml
│   └── psp-migration.yaml
├── 03-opa-gatekeeper/
│   ├── installation.yaml
│   ├── constraints/
│   │   ├── require-ingress-tls.yaml
│   │   └── container-limits.yaml
│   └── constraint-templates/
│       ├── k8srequiredlabels.yaml
│       └── containerresourcelimits.yaml
├── 04-pod-security/
│   ├── pss-baseline.yaml
│   ├── pss-restricted.yaml
│   └── warnings.yaml
├── 05-test-workloads/
│   ├── compliant-pod.yaml
│   ├── non-compliant-pod.yaml
│   └── privileged-pod.yaml
└── 06-validation/
    ├── validating-webhook.yaml
    └── mutating-webhook.yaml
```

## Подробное выполнение задания

### 1. Установка и настройка Kyverno

**Файл: `01-kyverno-install.yaml`**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: kyverno
  labels:
    pod-security.kubernetes.io/enforce: privileged
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kyverno
  namespace: kyverno
  labels:
    app: kyverno
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kyverno
  template:
    metadata:
      labels:
        app: kyverno
    spec:
      serviceAccountName: kyverno
      containers:
      - name: kyverno
        image: kyverno/kyverno:v1.10.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 443
          name: webhook
          protocol: TCP
        - containerPort: 5443
          name: metrics
          protocol: TCP
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1024Mi
        livenessProbe:
          httpGet:
            path: /health/liveness
            port: 5443
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /health/readiness
            port: 5443
            scheme: HTTP
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
---
# Service Account для Kyverno
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kyverno
  namespace: kyverno
---
# ClusterRole для доступа Kyverno к ресурсам
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kyverno
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
# Привязка ClusterRole к ServiceAccount
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kyverno
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kyverno
subjects:
- kind: ServiceAccount
  name: kyverno
  namespace: kyverno
```

### 2. Создание политик Kyverno

**Файл: `02-kyverno-policies/require-labels.yaml`**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
  annotations:
    policies.kyverno.io/title: Require Labels
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
spec:
  validationFailureAction: enforce  # enforce - блокирует, audit - только предупреждает
  background: true                  # Проверять существующие ресурсы
  rules:
  - name: check-for-labels
    match:
      resources:
        kinds:
        - Pod
        - Deployment
        - StatefulSet
        - DaemonSet
    validate:
      message: "Все Pod'ы должны иметь labels 'app' и 'version'"
      pattern:
        metadata:
          labels:
            app: "?*"           # ?* означает обязательное непустое значение
            version: "?*"
```

**Файл: `02-kyverno-policies/disallow-privileged.yaml`**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged-containers
  annotations:
    policies.kyverno.io/title: Disallow Privileged Containers
    policies.kyverno.io/category: Security
    policies.kyverno.io/severity: high
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: block-privileged
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Privileged контейнеры запрещены. Поле 'privileged' должно быть false или отсутствовать."
      pattern:
        spec:
          containers:
          - =(securityContext):
              =(privileged): false
  - name: block-privileged-init
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Init контейнеры не могут быть privileged."
      pattern:
        spec:
          =(initContainers):
          - =(securityContext):
              =(privileged): false
```

**Файл: `02-kyverno-policies/require-resource-limits.yaml`**
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  annotations:
    policies.kyverno.io/title: Require Resource Limits
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: validate-resources
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Все контейнеры должны иметь установленные resource limits и requests."
      pattern:
        spec:
          containers:
          - name: "*"
            resources:
              limits:
                memory: "?*"
                cpu: "?*"
              requests:
                memory: "?*"
                cpu: "?*"
```

### 3. Установка и настройка OPA Gatekeeper

**Файл: `03-opa-gatekeeper/installation.yaml`**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gatekeeper-controller-manager
  namespace: gatekeeper-system
  labels:
    control-plane: controller-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      control-plane: controller-manager
  template:
    metadata:
      labels:
        control-plane: controller-manager
    spec:
      serviceAccountName: gatekeeper-admin
      containers:
      - name: manager
        image: openpolicyagent/gatekeeper:v3.12.0
        args:
        - --port=8443
        - --log-level=INFO
        - --exempt-namespace=gatekeeper-system
        - --operation=webhook
        - --disable-opa-builtin=http.send
        resources:
          limits:
            cpu: 1000m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8443
            scheme: HTTPS
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8443
            scheme: HTTPS
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
---
apiVersion: v1
kind: Service
metadata:
  name: gatekeeper-webhook-service
  namespace: gatekeeper-system
spec:
  ports:
  - port: 443
    targetPort: 8443
  selector:
    control-plane: controller-manager
```

### 4. Constraint Templates для OPA Gatekeeper

**Файл: `03-opa-gatekeeper/constraint-templates/k8srequiredlabels.yaml`**
```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
        listKind: K8sRequiredLabelsList
        plural: k8srequiredlabels
        singular: k8srequiredlabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package k8srequiredlabels

      violation[{"msg": msg, "details": {"missing_labels": missing}}] {
        provided := {label | input.review.object.metadata.labels[label]}
        required := {label | label := input.parameters.labels[_]}
        missing := required - provided
        count(missing) > 0
        msg := sprintf("Вы обязаны указать labels: %v", [missing])
      }
```

**Файл: `03-opa-gatekeeper/constraint-templates/containerresourcelimits.yaml`**
```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: containerresourcelimits
spec:
  crd:
    spec:
      names:
        kind: ContainerResourceLimits
        listKind: ContainerResourceLimitsList
        plural: containerresourcelimits
        singular: containerresourcelimits
      validation:
        openAPIV3Schema:
          type: object
          properties:
            limits:
              type: boolean
            requests:
              type: boolean
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package containerresourcelimits

      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        not container.resources.limits
        input.parameters.limits
        msg := sprintf("Контейнер %v не имеет resource limits", [container.name])
      }

      violation[{"msg": msg}] {
        container := input.review.object.spec.containers[_]
        not container.resources.requests
        input.parameters.requests
        msg := sprintf("Контейнер %v не имеет resource requests", [container.name])
      }
```

### 5. Constraints для применения политик

**Файл: `03-opa-gatekeeper/constraints/require-ingress-tls.yaml`**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-app-version-labels
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
    namespaces:
    - "default"
    - "production"
  parameters:
    labels:
    - "app"
    - "version"
```

**Файл: `03-opa-gatekeeper/constraints/container-limits.yaml`**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: ContainerResourceLimits
metadata:
  name: require-resource-limits
spec:
  match:
    kinds:
    - apiGroups: [""]
      kinds: ["Pod"]
  parameters:
    limits: true
    requests: true
```

### 6. Pod Security Standards

**Файл: `04-pod-security/pss-baseline.yaml`**
```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1
    kind: PodSecurityConfiguration
    defaults:
      enforce: "baseline"
      enforce-version: "latest"
      audit: "restricted"
      audit-version: "latest"
      warn: "restricted"
      warn-version: "latest"
    exemptions:
      usernames: []
      runtimeClasses: []
      namespaces:
      - "kube-system"
      - "gatekeeper-system"
      - "kyverno"
```

### 7. Тестовые workloads

**Файл: `05-test-workloads/compliant-pod.yaml`**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: compliant-pod
  namespace: default
  labels:
    app: nginx
    version: "1.0"
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
```

**Файл: `05-test-workloads/non-compliant-pod.yaml`**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: non-compliant-pod
  namespace: default
  # Отсутствуют обязательные labels
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    # Отсутствуют resource limits
    securityContext:
      privileged: true  # Запрещенная настройка
```

### 8. Custom Admission Webhooks

**Файл: `06-validation/validating-webhook.yaml`**
```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: custom-security-validation
webhooks:
- name: custom-security.kubernetes.io
  clientConfig:
    service:
      name: custom-validation-service
      namespace: default
      path: /validate
    caBundle: ${CA_BUNDLE}  # Заменить на реальный CA bundle
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: [""]
    apiVersions: ["v1"]
    resources: ["pods"]
  failurePolicy: Fail
  sideEffects: None
  admissionReviewVersions: ["v1", "v1beta1"]
```

## Пошаговое выполнение

### Шаг 1: Установка Kyverno
```bash
# Установка Kyverno
kubectl apply -f 01-kyverno-install.yaml

# Проверка установки
kubectl get pods -n kyverno
kubectl get clusterpolicies
```

### Шаг 2: Применение политик Kyverno
```bash
# Применение всех политик Kyverno
kubectl apply -f 02-kyverno-policies/

# Проверка политик
kubectl get clusterpolicies

# Проверка конкретной политики
kubectl describe clusterpolicy require-labels
```

### Шаг 3: Установка OPA Gatekeeper
```bash
# Создание namespace для Gatekeeper
kubectl create namespace gatekeeper-system

# Установка Gatekeeper
kubectl apply -f 03-opa-gatekeeper/installation.yaml

# Проверка установки
kubectl get pods -n gatekeeper-system
```

### Шаг 4: Применение Constraint Templates и Constraints
```bash
# Применение Constraint Templates
kubectl apply -f 03-opa-gatekeeper/constraint-templates/

# Применение Constraints
kubectl apply -f 03-opa-gatekeeper/constraints/

# Проверка
kubectl get constrainttemplates
kubectl get k8srequiredlabels
```

### Шаг 5: Тестирование политик
```bash
# Попытка создать compliant pod (должен успешно создаться)
kubectl apply -f 05-test-workloads/compliant-pod.yaml

# Попытка создать non-compliant pod (должен быть заблокирован)
kubectl apply -f 05-test-workloads/non-compliant-pod.yaml

# Просмотр событий и нарушений
kubectl get events --sort-by='.lastTimestamp'
kubectl describe k8srequiredlabels require-app-version-labels
```

### Шаг 6: Мониторинг и аудит
```bash
# Проверка нарушений в Kyverno
kubectl get policyreports -A

# Проверка нарушений в Gatekeeper
kubectl get constraints
kubectl describe containerresourcelimits require-resource-limits

# Просмотр логов admission controllers
kubectl logs -n kyverno -l app=kyverno
kubectl logs -n gatekeeper-system -l control-plane=controller-manager
```

## Ключевые концепции

### 1. Admission Controllers
- **ValidatingAdmissionWebhook**: Проверяет и валидирует запросы
- **MutatingAdmissionWebhook**: Изменяет запросы перед сохранением
- **PodSecurity**: Встроенный admission controller для Pod Security Standards

### 2. Policy Engines
**Kyverno:**
- Политики как Kubernetes ресурсы
- Поддержка validate, mutate, generate
- Не требует знания Rego

**OPA Gatekeeper:**
- Использует язык Rego для политик
- Более гибкий, но сложнее в освоении
- Constraint Templates + Constraints

### 3. Типы политик
- **Validation**: Проверка соответствия требованиям
- **Mutation**: Автоматическое исправление конфигураций
- **Generation**: Создание дополнительных ресурсов

### 4. Режимы работы
- **enforce**: Блокирует несоответствующие ресурсы
- **audit**: Только предупреждения и логирование
- **warn**: Предупреждения пользователю без блокировки

## Расширенные сценарии

### 1. Миграция с PodSecurityPolicy
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: psp-migration
spec:
  rules:
  - name: psp-equivalent
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Эквивалент PSP политики"
      pattern:
        spec:
          containers:
          - securityContext:
              =(runAsNonRoot): true
              =(privileged): false
              =(allowPrivilegeEscalation): false
              capabilities:
                drop:
                - ALL
```

### 2. Комплексные политики безопасности
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: comprehensive-security
spec:
  rules:
  - name: require-security-context
    match:
      resources:
        kinds:
        - Pod
    validate:
      pattern:
        spec:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          containers:
          - securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                - ALL
```

### 3. Мониторинг и отчетность
```bash
# Установка Kyverno CLI для тестирования политик
curl -s https://api.github.com/repos/kyverno/kyverno/releases/latest | \
jq -r '.assets[] | select(.name | test("kyverno-cli.*linux-x86_64.tar.gz")) | .browser_download_url' | \
xargs curl -L -o kyverno-cli.tar.gz && tar -xzf kyverno-cli.tar.gz

# Тестирование политик локально
./kyverno test . --test-case-selector policy=require-labels
```

Это задание демонстрирует полный цикл настройки и использования Policy Engines и Admission Controllers для обеспечения безопасности Kubernetes кластера, включая установку, конфигурацию, тестирование и мониторинг политик безопасности.