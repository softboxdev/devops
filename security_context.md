# Создание Pod с Security Context: Подробное руководство

## 1. Понимание манифеста

Разберем каждый параметр вашего манифеста:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-demo
spec:
  securityContext:           # Настройки безопасности для ВСЕГО Pod
    runAsUser: 1000         # Запуск от пользователя с UID 1000
    runAsGroup: 3000        # Запуск от группы с GID 3000  
    fsGroup: 2000           # GID для файловой системы
    runAsNonRoot: true      # Запрет запуска от root
  containers:
  - name: sec-ctx-demo
    image: busybox
    command: ["sh", "-c", "sleep 1h"]
    securityContext:        # Настройки безопасности для КОНТЕЙНЕРА
      allowPrivilegeEscalation: false  # Запрет повышения привилегий
      capabilities:
        drop:
        - ALL               # Удаление ВСЕХ Linux capabilities
      readOnlyRootFilesystem: true     # ФС только для чтения
```

## 2. Пошаговое создание Pod

### 2.1 Создание файла манифеста

```bash
# Создаем файл с манифестом
cat > security-pod.yaml << EOF
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
EOF
```

### 2.2 Применение манифеста

```bash
# Создаем Pod в кластере
kubectl apply -f security-pod.yaml

# Проверяем статус
kubectl get pods security-context-demo

# Смотрим детали Pod
kubectl describe pod security-context-demo
```

### 2.3 Проверка создания

```bash
# Ждем когда Pod перейдет в состояние Running
kubectl wait --for=condition=ready pod/security-context-demo --timeout=60s

# Проверяем логи (если нужно)
kubectl logs security-context-demo
```

## 3. Проверка работы security context

### 3.1 Проверка пользователя и группы

```bash
# Заходим в контейнер и проверяем пользователя
kubectl exec -it security-context-demo -- sh

# Внутри контейнера выполняем:
whoami                    # Должен показать UID 1000
id                        # Покажет uid=1000 gid=3000 groups=2000
ps aux                    # Покажет процессы от пользователя 1000

# Проверяем файловую систему
mount | grep rootfs       # Увидим что корневая ФС только для чтения
touch /test.txt           # Должна быть ошибка - read-only filesystem
```

### 3.2 Проверка capabilities

```bash
# Проверяем Linux capabilities
kubectl exec security-context-demo -- cat /proc/1/status | grep Cap

# Должны увидеть пустые capabilities:
CapInh: 0000000000000000
CapPrm: 0000000000000000
CapEff: 0000000000000000
CapBnd: 0000000000000000
CapAmb: 0000000000000000
```

## 4. Объяснение параметров безопасности

### 4.1 Pod-level securityContext

```yaml
spec:
  securityContext:
    runAsUser: 1000        # Запускает ВСЕ контейнеры в Pod от пользователя UID 1000
    runAsGroup: 3000       # Запускает ВСЕ контейнеры от группы GID 3000
    fsGroup: 2000          # Создает файлы с GID 2000 и дает права группе
    runAsNonRoot: true     # Блокирует запуск если UID = 0 (root)
```

**Что это дает:**
- ✅ Процессы не работают от root
- ✅ Файлы создаются с правильными правами
- ✅ Автоматическая проверка на root

### 4.2 Container-level securityContext

```yaml
containers:
- securityContext:
    allowPrivilegeEscalation: false  # Нельзя стать root через su/sudo
    capabilities:
      drop:
      - ALL                          # Удаляет все специальные права
    readOnlyRootFilesystem: true     # Защита от изменения системных файлов
```

**Что это дает:**
- ✅ Невозможно повысить привилегии
- ✅ Контейнер не может делать опасные операции (монтирование, raw socket)
- ✅ Защита от модификации вредоносным кодом

## 5. Решение возможных проблем

### 5.1 Ошибка: "container has runAsNonRoot and image will run as root"

**Проблема:**
```bash
Error: container has runAsNonRoot and image will run as root
```

**Решение:**
```yaml
# Убедитесь что в Dockerfile указан USER
# Или используйте образы которые по умолчанию не работают от root

# Альтернативно - создайте пользователя в манифесте
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true
```

### 5.2 Ошибка: "permission denied" при записи

**Проблема:**
Контейнеру нужно писать в определенные директории

**Решение:**
```yaml
spec:
  containers:
  - name: sec-ctx-demo
    # ...
    volumeMounts:
    - name: temp-volume
      mountPath: /tmp
      readOnly: false
  volumes:
  - name: temp-volume
    emptyDir: {}
```

### 5.3 Проверка перед запуском

```bash
# Валидация манифеста
kubectl apply --dry-run=client -f security-pod.yaml

# Проверка синтаксиса
kubeval security-pod.yaml

# Линтинг манифеста
kube-score score security-pod.yaml
```

## 6. Расширенная конфигурация

### 6.1 Добавление необходимых capabilities

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: security-context-advanced
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault    # Профиль безопасности seccomp
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
        add:
        - NET_BIND_SERVICE   # Разрешаем только привязку к портам <1024
      readOnlyRootFilesystem: true
      privileged: false      # Явно запрещаем privileged mode
```

### 6.2 Настройка SELinux/AppArmor

```yaml
spec:
  securityContext:
    seLinuxOptions:
      level: "s0:c123,c456"
  containers:
  - securityContext:
      appArmorProfile: runtime/default
```

## 7. Best Practices для security context

### 7.1 Обязательные настройки для production

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: production-safe-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10000        # Высокий UID вне стандартного диапазона
    runAsGroup: 10000
    fsGroup: 10000
  containers:
  - name: app
    image: your-app:latest
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      readOnlyRootFilesystem: true
      runAsUser: 10000      # Дублируем на уровне контейнера для ясности
```

### 7.2 Контрольный список безопасности

```bash
# Проверка настроек безопасности
kubectl get pod security-context-demo -o json | jq '.spec.securityContext'
kubectl get pod security-context-demo -o json | jq '.spec.containers[0].securityContext'

# Проверка через kube-score
kube-score score security-pod.yaml
```

## 8. Полезные команды для отладки

### 8.1 Проверка текущих настроек

```bash
# Экспорт текущей конфигурации Pod
kubectl get pod security-context-demo -o yaml > current-pod.yaml

# Проверка пользователя в запущенном Pod
kubectl exec security-context-demo -- id

# Проверка capabilities
kubectl exec security-context-demo -- capsh --print

# Проверка монтирования файловой системы
kubectl exec security-context-demo -- mount | grep -E '(rootfs|/)'
```

### 8.2 Мониторинг нарушений безопасности

```bash
# Просмотр событий безопасности
kubectl get events --field-selector reason=FailedCreate

# Проверка аудита (если включен)
kubectl logs -l component=kube-apiserver -n kube-system | grep -i security
```

## 9. Удаление Pod

```bash
# Удаление созданного Pod
kubectl delete -f security-pod.yaml

# Или по имени
kubectl delete pod security-context-demo

# Проверка что Pod удален
kubectl get pods | grep security-context-demo
```

## Заключение

Ваш манифест правильно настроен с точки зрения безопасности:

- ✅ **Защита от root** - `runAsNonRoot: true`
- ✅ **Нет привилегий** - `allowPrivilegeEscalation: false`  
- ✅ **Минимальные права** - `capabilities.drop: [ALL]`
- ✅ **Защита ФС** - `readOnlyRootFilesystem: true`

Это отличная базовая конфигурация для production-workloads! 🚀