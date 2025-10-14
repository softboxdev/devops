# Защита Control Plane кластера Kubernetes: Подробное объяснение для новичков

## 1. Что такое Control Plane?

### 1.1 Простая аналогия: "Мозг" кластера

**Control Plane** - это **управляющий центр** всего кластера Kubernetes. Представьте себе:

- 🎮 **Control Plane = Диспетчерская такси**
- 🚗 **Worker Nodes = Такси на дорогах**
- 👥 **Pods = Пассажиры в такси**

**Диспетчерская (Control Plane):**
- Принимает заказы (создание Pods)
- Распределяет такси по заказам (распределение Pods по Nodes)
- Следит за состоянием такси (мониторинг Nodes)
- Хранит информацию о всех заказах (etcd)

### 1.2 Компоненты Control Plane

```
Control Plane состоит из:
├── kube-apiserver - "Входная дверь" кластера
├── etcd - "База данных" кластера  
├── kube-scheduler - "Менеджер по распределению"
├── kube-controller-manager - "Автоматизатор процессов"
└── cloud-controller-manager - "Интегратор с облаком"
```

## 2. Почему защита Control Plane критически важна?

### 2.1 Последствия компрометации Control Plane

Если злоумышленник получает доступ к Control Plane:

- ✅ **Может создавать/удалять ЛЮБЫЕ ресурсы**
- ✅ **Может читать ЛЮБЫЕ секреты (пароли, ключи)**
- ✅ **Может изменять правила безопасности**
- ✅ **Может остановить ВЕСЬ кластер**
- ✅ **Может украсть ВСЕ данные приложений**

### 2.2 Реальные риски

```bash
# Пример: что может сделать злоумышленник
kubectl get secrets --all-namespaces          # Украсть все пароли
kubectl delete all --all --all-namespaces     # Удалить всё в кластере
kubectl create pod --image=malware/backdoor   # Запустить вредоносный код
```

## 3. Основные угрозы Control Plane

### 3.1 Сетевые атаки
- **Неавторизованный доступ** к API Server
- **Атаки типа Man-in-the-Middle**
- **DDoS атаки** на API endpoints

### 3.2 Атаки на etcd
- **Кража данных** из базы etcd
- **Изменение конфигурации** кластера
- **Удаление критических данных**

### 3.3 Неправильная конфигурация
- **Слабые настройки аутентификации**
- **Открытые порты** для внешнего доступа
- **Отсутствие обновлений безопасности**

## 4. Практические меры защиты

### 4.1 Сетевая изоляция

#### 4.1.1 Ограничение доступа к API Server
```bash
# ПЛОХО: API Server доступен из интернета
kube-apiserver --bind-address=0.0.0.0

# ХОРОШО: API Server доступен только из внутренней сети
kube-apiserver --bind-address=192.168.1.100
```

#### 4.1.2 Использование Private Networks
```yaml
# Пример настройки в облаке (AWS VPC)
Network:
  VPC CIDR: 10.0.0.0/16
  Public Subnet: 10.0.1.0/24    # Для Load Balancers
  Private Subnet: 10.0.2.0/24   # Для Control Plane
  Data Subnet: 10.0.3.0/24      # Для Worker Nodes
```

### 4.2 Аутентификация и авторизация

#### 4.2.1 Настройка RBAC
```yaml
# Минимальные права для администратора
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-admin-limited
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
```

#### 4.2.2 Использование Service Accounts
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: safe-application
  namespace: production
automountServiceAccountToken: false  # Важно для безопасности
```

### 4.3 Шифрование данных

#### 4.3.1 Шифрование etcd
```yaml
# Создание EncryptionConfig
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
    - secrets
    providers:
    - aescbc:
        keys:
        - name: key1
          secret: <base64-encoded-secret>
    - identity: {}  # Резервный провайдер
```

#### 4.3.2 Шифрование в rest
```bash
# Включение шифрования при установке кластера
kube-apiserver --encryption-provider-config=/etc/kubernetes/encryption-config.yaml
```

### 4.4 Регулярное обновление

#### 4.4.1 Политика обновлений
```bash
# Проверка текущей версии
kubectl version --short

# Рекомендуемый цикл обновлений
┌─────────────┬──────────────────────────────┐
│ Версия      │ Поддержка безопасности       │
├─────────────┼──────────────────────────────┤
│ 1.28        │ До сентября 2024            │
│ 1.27        │ До июля 2024                │
│ 1.26        │ До апреля 2024              │
└─────────────┴──────────────────────────────┘
```

## 5. Защита отдельных компонентов Control Plane

### 5.1 kube-apiserver защита

#### 5.1.1 Настройка флагов безопасности
```bash
# Безопасная конфигурация API Server
kube-apiserver \
  --anonymous-auth=false \                    # Отключить анонимный доступ
  --authorization-mode=Node,RBAC \           # Включить RBAC
  --enable-admission-plugins=PodSecurityPolicy \  # Политики безопасности
  --audit-log-path=/var/log/audit.log \      # Аудит действий
  --audit-log-maxage=30 \                    # Хранить логи 30 дней
  --tls-cert-file=/path/to/cert.crt \        # TLS сертификаты
  --tls-private-key-file=/path/to/cert.key
```

### 5.2 etcd защита

#### 5.2.1 Настройки безопасности etcd
```bash
# Безопасная конфигурация etcd
etcd \
  --client-cert-auth=true \                  # Требовать клиентские сертификаты
  --auto-tls=false \                         # Отключить авто-TLS
  --peer-client-cert-auth=true \             # Аутентификация между etcd узлами
  --trusted-ca-file=/path/to/ca.crt \        # Доверенные CA
  --cert-file=/path/to/server.crt \          # Сертификат сервера
  --key-file=/path/to/server.key             # Приватный ключ
```

### 5.3 kube-controller-manager и kube-scheduler

#### 5.3.1 Защита вторичных компонентов
```bash
# kube-controller-manager
kube-controller-manager \
  --use-service-account-credentials=true \   # Использовать Service Accounts
  --root-ca-file=/path/to/ca.crt \           # Корневой CA
  --service-account-private-key-file=/path/to/sa.key

# kube-scheduler  
kube-scheduler \
  --bind-address=127.0.0.1 \                 # Только localhost
  --leader-elect=true                        # Выбор лидера для HA
```

## 6. Мониторинг и аудит

### 6.1 Настройка аудита
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata                         # Уровень логирования
  namespaces: ["kube-system"]             # Особое внимание к системным namespace
  verbs: ["delete", "create", "update"]   # Критические операции
  resources:
  - group: ""                             # Core API group
    resources: ["secrets", "configmaps"]
```

### 6.2 Мониторинг аномалий
```yaml
# Пример правила для Falco (runtime security)
- rule: Unexpected K8s NodePort Connection
  desc: Detect connections to NodePort services from outside expected ranges
  condition: >
    evt.type=connect and evt.dir=< and 
    (fd.sport=30000-32767 or fd.sport=20000-20050)
  output: >
    Unexpected connection to K8s NodePort (fd.sport=%fd.sport)
  priority: WARNING
```

## 7. Backup и Disaster Recovery

### 7.1 Регулярное резервное копирование etcd
```bash
#!/bin/bash
# Скрипт backup etcd

ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /backup/etcd-snapshot-$(date +%Y%m%d).db
```

### 7.2 План восстановления
```bash
# Восстановление из snapshot
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-snapshot.db \
  --data-dir /var/lib/etcd-from-backup
```

## 8. Инструменты для проверки безопасности

### 8.1 kube-bench (CIS Benchmark)
```bash
# Запуск проверки безопасности
docker run --rm --pid=host -v /etc:/etc:ro -v /var:/var:ro \
  aquasec/kube-bench:latest run --targets master

# Проверка результатов
cat results/master.json | jq '.tests[].results[] | select(.status == "FAIL")'
```

### 8.2 kube-hunter
```bash
# Сканирование на уязвимости
kube-hunter --remote <control-plane-ip>

# Пассивное сканирование
kube-hunter --passive
```

## 9. Best Practices для новичков

### 9.1 "Не навреди" - базовые правила

1. **✅ НИКОГДА не открывайте API Server в интернет**
2. **✅ ВСЕГДА используйте RBAC**
3. **✅ РЕГУЛЯРНО обновляйте кластер**
4. **✅ ШИФРУЙТЕ секреты в etcd**
5. **✅ НАСТРАИВАЙТЕ аудит важных операций**

### 9.2 Контрольный список безопасности

```markdown
- [ ] API Server доступен только из trusted networks
- [ ] RBAC включен и настроен
- [ ] etcd зашифрован и защищен
- [ ] Регулярные backup etcd
- [ ] Включен аудит безопасности
- [ ] TLS сертификаты валидны
- [ ] Кластер обновлен до последней стабильной версии
- [ ] Network policies настроены
- [ ] Pod security policies включены
```

## 10. Пример безопасной архитектуры

### 10.1 Типовая схема для production
```
┌─────────────────────────────────────────────────────────────┐
│                    INTERNET                                 │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                 Load Balancer (Public)                      │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                 Bastion Host / VPN                          │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                 PRIVATE NETWORK                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Control     │  │ Control     │  │ Control     │         │
│  │ Plane 1     │  │ Plane 2     │  │ Plane 3     │         │
│  │ 10.0.1.10   │  │ 10.0.1.11   │  │ 10.0.1.12   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│           │              │              │                  │
│           └──────────────┼──────────────┘                  │
│                          │                                 │
│                 ┌────────▼────────┐                        │
│                 │   Load Balancer │                        │
│                 │   (Internal)    │                        │
│                 └─────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## Заключение

Защита Control Plane - это **фундамент безопасности** всего Kubernetes кластера. Начните с базовых мер:

1. **Сетевая изоляция** - самый важный первый шаг
2. **RBAC** - контроль доступа
3. **Шифрование** - защита данных
4. **Обновления** - закрытие уязвимостей
5. **Мониторинг** - обнаружение угроз

Помните: безопасность - это процесс, а не разовое действие. Регулярно пересматривайте и улучшайте защиту вашего Control Plane.