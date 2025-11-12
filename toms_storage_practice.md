
# 💾 Подробное объяснение Томов и Хранилищ в Kubernetes

## 🏢 Аналогия: Представим что Kubernetes - это большой офис

**Давайте представим:**
- **Pod** = Рабочее место сотрудника (стол, компьютер)
- **Volume (Том)** = Ящики и папки для хранения документов
- **emptyDir** = Временная папка на столе (исчезает после работы)
- **Persistent Volume (PV)** = Шкаф для хранения в офисе
- **Persistent Volume Claim (PVC)** = Заявка на выделение шкафа

## 1. 📦 Что такое Тома (Volumes)?

### 🤔 Простыми словами:

**Том - это "место для хранения данных"** в вашем Pod, которое:
- Позволяет сохранять файлы между перезапусками контейнеров
- Дает возможность обмениваться данными между контейнерами в одном Pod
- Сохраняет важную информацию когда Pod перезапускается

### 📖 Техническое определение:

**Volume** - это директория возможно с данными в ней, которая доступна контейнерам в Pod. В отличие от диска контейнера, данные в volume сохраняются при перезапуске контейнера.

### 🎯 Зачем нужны тома?

**Без томов:**
```bash
# Контейнер как "чистый лист" при каждом запуске
[ Запуск Pod ] → "Привет, я новый!"
[ Сохраняем файл ] → "important_data.txt"
[ Перезапуск Pod ] → "Привет, я новый! Где мои файлы?" 😢
```

**С томами:**
```bash
# Контейнер с "памятью"
[ Запуск Pod ] → "Привет! У меня есть том для хранения"
[ Сохраняем файл ] → "important_data.txt" → [ Volume ]
[ Перезапуск Pod ] → "Привет! А вот и мои файлы!" 😊
```

## 2. 🗂️ Что такое emptyDir?

### 🤔 Простыми словами:

**emptyDir - это "временная папка на рабочем столе"** которая:
- Создается когда сотрудник приходит на работу (Pod запускается)
- Исчезает когда сотрудник уходит домой (Pod удаляется)
- Отлично подходит для временных файлов и обмена данными между коллегами

### 📖 Техническое определение:

**emptyDir** - это том который создается когда Pod назначается на ноду, и существует пока Pod работает на этой ноде. При удалении Pod данные в emptyDir теряются.

### 🎯 Когда использовать emptyDir:

1. **Кэширование** - временные файлы, кэш приложения
2. **Обмен данными** - между контейнерами в одном Pod
3. **Временные вычисления** - промежуточные результаты
4. **Checkpointing** - точки сохранения долгих операций

### 🛠️ Пример emptyDir:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-workspace-pod
spec:
  containers:
  - name: writer
    image: alpine:3.18
    command: ["/bin/sh"]
    args: ["-c", "echo 'Данные от писателя' > /shared-data/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared-storage
      mountPath: /shared-data  # Монтируем том в эту папку
      
  - name: reader
    image: alpine:3.18
    command: ["/bin/sh"]
    args: ["-c", "cat /shared-data/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared-storage
      mountPath: /shared-data  # Тот же том в другую папку
      
  volumes:
  - name: shared-storage
    emptyDir: {}  # Вот наш временный том!
```

### 💡 Как это работает:

```
[ Pod: shared-workspace-pod ]
    ↓
[ Контейнер: writer ] → /shared-data/message.txt
    ↓              ↗
[ Том: emptyDir ]  
    ↓              ↘  
[ Контейнер: reader ] → /shared-data/message.txt
```

**Writer пишет:** `"Данные от писателя"` → **emptyDir том**  
**Reader читает:** `"Данные от писателя"` ← **emptyDir том**

### 🎯 Особенности emptyDir:

- **⚡ Быстрый** - обычно создается на локальном диске ноды
- **🧹 Временный** - данные удаляются при удалении Pod
- **🔁 Общий** - несколько контейнеров могут использовать один том
- **💾 В памяти** - можно настроить использование RAM вместо диска

### 🛠️ emptyDir в памяти:

```yaml
volumes:
- name: memory-storage
  emptyDir:
    medium: Memory    # Используем RAM вместо диска!
    sizeLimit: 64Mi   # Максимальный размер
```

## 3. 🗄️ Что такое Persistent Volume (PV) и Persistent Volume Claim (PVC)?

### 🤔 Простыми словами:

**Persistent Volume (PV) - это "шкаф для хранения в офисе"** который:
- Существует независимо от рабочих мест (Pod)
- Можно использовать разным сотрудникам в разное время
- Данные сохраняются даже когда все уходят домой

**Persistent Volume Claim (PVC) - это "заявка на шкаф"** которая:
- Описывает какой шкаф нужен (размер, тип)
- Резервирует шкаф для конкретного сотрудника
- Гарантирует что шкаф будет доступен когда нужно

### 📖 Технические определения:

**Persistent Volume (PV)** - ресурс хранилища в кластере который был подготовлен администратором или динамически создан с использованием Storage Classes.

**Persistent Volume Claim (PVC)** - запрос на хранение от пользователя. Это похоже на Pod - Pod потребляют ресурсы ноды, а PVC потребляют ресурсы PV.

### 🎯 Аналогия с офисом:

```
[ Администратор ] → [ Подготавливает шкафы ] → [ PV ]
                            ↓
[ Сотрудник ] → [ Заявка: "Нужен шкаф 1х1м" ] → [ PVC ]
                            ↓
[ Система ] → [ Выдает ключ от шкафа ] → [ Pod может использовать ]
```

### 🛠️ Как это выглядит в Kubernetes:

#### 1. **Persistent Volume (PV) - шкаф**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: office-cabinet-1
spec:
  capacity:
    storage: 10Gi  # Размер шкафа
  accessModes:
    - ReadWriteOnce  # Может использовать один сотрудник
  persistentVolumeReclaimPolicy: Retain
  storageClassName: standard
  hostPath:
    path: "/data/office-cabinet-1"  # Где физически находится
```

#### 2. **Persistent Volume Claim (PVC) - заявка**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: employee-storage-request
spec:
  accessModes:
    - ReadWriteOnce  # "Нужен шкаф для одного сотрудника"
  resources:
    requests:
      storage: 5Gi  # "Нужен шкаф размером 5 гигабайт"
  storageClassName: standard  # "Обычный шкаф подойдет"
```

#### 3. **Pod - сотрудник с доступом**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: employee-pod
spec:
  containers:
  - name: app
    image: nginx:1.25
    volumeMounts:
    - name: storage-volume
      mountPath: /data  # "Кладем файлы в шкаф"
  volumes:
  - name: storage-volume
    persistentVolumeClaim:
      claimName: employee-storage-request  # "Используем зарезервированный шкаф"
```

### 🎯 Access Modes (Режимы доступа):

#### 1. **ReadWriteOnce (RWO)**
- 📖 **Один читатель/писатель**
- 👤 **Только одна нода может монтировать**
- 💡 **Как: личный шкаф сотрудника**

```yaml
accessModes:
- ReadWriteOnce  # Только я могу читать и писать
```

#### 2. **ReadOnlyMany (ROX)**
- 📖 **Много читателей**
- 👥 **Много нод могут читать**
- 💡 **Как: библиотека с книгами**

```yaml
accessModes:
- ReadOnlyMany  # Все могут читать, но никто не может изменять
```

#### 3. **ReadWriteMany (RWX)**
- 📖 **Много читателей/писателей**
- 👥 **Много нод могут читать и писать**
- 💡 **Как: доска объявлений**

```yaml
accessModes:
- ReadWriteMany  # Все могут читать и писать
```

### 🎯 Dynamic Provisioning (Динамическое выделение):

**Вместо ручного создания PV, Kubernetes может создавать их автоматически!**

```yaml
# PVC с динамическим выделением
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-storage-request
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi  # "Хранилище создастся автоматически!"
  # storageClassName: standard - обычно есть по умолчанию
```

**Что происходит:**
1. Вы создаете PVC с запросом хранилища
2. Kubernetes смотрит на StorageClass
3. StorageClass создает новый PV автоматически
4. PVC связывается с созданным PV
5. Pod может использовать PVC

## 4. 🔄 Полный цикл работы с хранилищем

### 🎯 Статическое выделение (ручное):

```
[ Администратор ] → [ Создает PV ] → [ Доступные шкафы ]
                            ↓
[ Разработчик ] → [ Создает PVC ] → [ Заявка на шкаф ]
                            ↓
[ Kubernetes ] → [ Связывает PVC с PV ] → [ Биндинг ]
                            ↓
[ Разработчик ] → [ Создает Pod с PVC ] → [ Использование ]
```

### 🎯 Динамическое выделение (автоматическое):

```
[ Разработчик ] → [ Создает PVC ] → [ Заявка на шкаф ]
                            ↓
[ StorageClass ] → [ Автоматически создает PV ] → [ Новый шкаф ]
                            ↓
[ Kubernetes ] → [ Связывает PVC с PV ] → [ Биндинг ]
                            ↓
[ Разработчик ] → [ Создает Pod с PVC ] → [ Использование ]
```

## 5. 🏗️ Практические примеры использования

### 🎯 Пример 1: Веб-приложение с постоянным хранилищем

```yaml
# 1. Заявка на хранилище для веб-сайта
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: website-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi  # 5GB для файлов сайта

---
# 2. Веб-сервер который использует хранилище
apiVersion: apps/v1
kind: Deployment
metadata:
  name: website
spec:
  replicas: 2
  selector:
    matchLabels:
      app: website
  template:
    metadata:
      labels:
        app: website
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        volumeMounts:
        - name: web-data
          mountPath: /usr/share/nginx/html  # Файлы сайта тут
        ports:
        - containerPort: 80
      volumes:
      - name: web-data
        persistentVolumeClaim:
          claimName: website-storage  # Используем наше хранилище
```

### 🎯 Пример 2: База данных с постоянными данными

```yaml
# 1. Хранилище для базы данных
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi  # 20GB для данных БД

---
# 2. База данных которая использует хранилище
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-db
spec:
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: "mydatabase"
        - name: POSTGRES_PASSWORD
          value: "password123"
        volumeMounts:
        - name: db-data
          mountPath: /var/lib/postgresql/data  # Данные БД тут
        ports:
        - containerPort: 5432
      volumes:
      - name: db-data
        persistentVolumeClaim:
          claimName: database-storage  # Постоянное хранилище для БД
```

### 🎯 Пример 3: Приложение с разными типами томов

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: smart-application
spec:
  containers:
  - name: app
    image: my-app:1.0
    volumeMounts:
    - name: config-volume
      mountPath: /app/config
    - name: cache-volume
      mountPath: /app/cache
    - name: data-volume
      mountPath: /app/data
    - name: temp-volume
      mountPath: /app/temp
      
  volumes:
  - name: config-volume
    configMap:
      name: app-config  # ConfigMap для настроек
  
  - name: cache-volume
    emptyDir: {}  # Временный кэш
  
  - name: data-volume
    persistentVolumeClaim:
      claimName: app-data-pvc  # Постоянные данные
  
  - name: temp-volume
    emptyDir:
      medium: Memory  # Быстрый временный том в RAM
      sizeLimit: 512Mi
```

## 6. 🎓 Обучение через аналогии

### 🏢 Офисный центр (продолжение):

- **Pod** = Рабочее место сотрудника
- **emptyDir** = Временная папка на столе (исчезает после работы)
- **Persistent Volume (PV)** = Шкаф для документов в офисе
- **Persistent Volume Claim (PVC)** = Заявка на выделение шкафа
- **StorageClass** = Типы шкафов (маленькие, большие, с замком)

### 🏠 Строительство дома:

- **Pod** = Бригада строителей
- **emptyDir** = Инструменты на стройплощадке (забирают после работы)
- **Persistent Volume (PV)** = Склад строительных материалов
- **Persistent Volume Claim (PVC)** = Заявка на материалы со склада
- **StorageClass** = Виды материалов (кирпич, дерево, металл)

### 🎮 Видеоигра:

- **Pod** = Игровой персонаж
- **emptyDir** = Инвентарь персонажа (теряется при смерти)
- **Persistent Volume (PV)** = Банк в игре
- **Persistent Volume Claim (PVC)** = Запрос на ячейку в банке
- **StorageClass** = Типы ячеек (маленькие, большие, премиум)

## 7. 💡 Ключевые преимущества

### 🎯 Тома дают:

1. **Сохранение данных** - файлы не теряются при перезапуске контейнера
2. **Обмен данными** - несколько контейнеров могут работать с одними файлами
3. **Гибкость** - разные типы хранилищ для разных нужд
4. **Переносимость** - данные могут перемещаться между нодами

### 🎯 emptyDir дает:

1. **Простота** - легко создать и использовать
2. **Скорость** - обычно на быстром локальном диске
3. **Временность** - не нужно беспокоиться об очистке
4. **Совместное использование** - идеально для контейнеров в одном Pod

### 🎯 PVC/PV дают:

1. **Постоянство** - данные живут дольше чем Pod
2. **Динамичность** - автоматическое выделение хранилища
3. **Абстракция** - не нужно думать о физическом хранилище
4. **Управление** - централизованное управление хранилищем

## 8. 🚨 Частые ошибки новичков

### ❌ "Данные в emptyDir пропали!"

**Это нормально!** emptyDir предназначен для временных данных. Для постоянного хранения используйте PVC.

### ❌ "PVC в статусе Pending"

**Возможные причины:**
- Нет подходящего PV (проверьте `kubectl get pv`)
- Неправильный storageClass
- Запрошенный размер больше доступного

### ❌ "Не могу удалить PVC"

**PVC защищены если используются Pod!**
Сначала удалите Pod который использует PVC, потом удаляйте PVC.

### ❌ "Данные не сохраняются между Pod"

**Проверьте:**
- Используете ли вы Persistent Volume (не emptyDir)
- PVC правильно подключен к Pod
- Access modes разрешают нужный тип доступа

## 9. 🛠️ Полезные команды для работы

```bash
# Посмотреть тома в Pod
kubectl describe pod <pod-name>

# Посмотреть PVC
kubectl get pvc

# Посмотреть PV
kubectl get pv

# Посмотреть StorageClass
kubectl get storageclass

# Проверить использование диска в Pod
kubectl exec <pod> -- df -h

# Описать PVC для диагностики
kubectl describe pvc <pvc-name>
```

## 10. 🎯 Итоговое понимание

### После этого объяснения вы должны понимать что:

1. **Volume** = Место для хранения данных в Pod
2. **emptyDir** = Временная папка (исчезает с Pod)
3. **Persistent Volume (PV)** = Постоянное хранилище в кластере
4. **Persistent Volume Claim (PVC)** = Запрос на выделение хранилища
5. **StorageClass** = Тип и настройки хранилища

### 💪 Теперь когда вы понимаете концепции:

- **emptyDir** - это не магия, а просто временная папка
- **PVC/PV** - это система "заявка-хранилище" как в библиотеке
- **StorageClass** - это "каталог типов хранилищ"
- **Всё вместе** - это мощная система для управления данными в приложениях

### 🎯 Когда что использовать:

- **emptyDir** → Кэш, временные файлы, обмен данными между контейнерами
- **PVC/PV** → Базы данных, файлы пользователей, логи, бэкапы
- **ConfigMap/Secret** → Настройки и пароли (не для больших данных!)


# 🗂️ Практическое руководство по Kubernetes: Тома и хранилища

## 📋 Предварительная настройка

### 1. Запуск Minikube с поддержкой хранилища

```bash
# Запускаем Minikube с дополнительными функциями для хранилища
minikube start --memory=4096 --cpus=2 --driver=docker --addons=storage-provisioner

# Проверяем
kubectl get nodes
minikube status

# Создаем рабочую директорию
mkdir ~/k8s-storage-practice && cd ~/k8s-storage-practice

# Проверяем storage classes
kubectl get storageclass
```

### 2. Понимание типов томов в Kubernetes

**Основные концепции:**
- **emptyDir**: Временное хранилище, живет пока жив Pod
- **hostPath**: Хранилище на узле (ноде)
- **PersistentVolume (PV)**: Ресурс хранилища в кластере
- **PersistentVolumeClaim (PVC)**: Запрос на выделение PV

---

## 📁 ЧАСТЬ 1: Временные тома (emptyDir)

### 🎯 Задание 1.1: Создание Pod с emptyDir

**Теория:**
- `emptyDir` создается при запуске Pod и удаляется при его остановке
- Используется для обмена данными между контейнерами в одном Pod
- Данные сохраняются при рестартах контейнеров, но не при рестарте Pod

**1. Создаем первый Pod с emptyDir:**
```yaml
# pod-emptydir.yaml
apiVersion: v1
kind: Pod
metadata:
  name: simple-emptydir-pod
  labels:
    app: storage-test
spec:
  containers:
  - name: writer-container
    image: alpine:3.18
    command: ["/bin/sh"]
    args: ["-c", "echo 'Hello from writer container!' > /shared-data/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared-storage
      mountPath: /shared-data
      
  - name: reader-container
    image: alpine:3.18
    command: ["/bin/sh"]
    args: ["-c", "cat /shared-data/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared-storage
      mountPath: /shared-data
      
  volumes:
  - name: shared-storage
    emptyDir: {}
```

**2. Применяем и тестируем:**
```bash
kubectl apply -f pod-emptydir.yaml

# Проверяем Pod
kubectl get pod simple-emptydir-pod

# Смотрим логи reader контейнера
kubectl logs simple-emptydir-pod -c reader-container

# Проверяем что записалось в том
kubectl exec simple-emptydir-pod -c writer-container -- cat /shared-data/message.txt
kubectl exec simple-emptydir-pod -c reader-container -- cat /shared-data/message.txt
```

**3. Упражнение: Измените сообщение**
```bash
# Зайдите в writer контейнер и измените сообщение
kubectl exec simple-emptydir-pod -c writer-container -it -- sh
echo "Новое сообщение!" > /shared-data/message.txt
exit

# Проверьте в reader контейнере
kubectl exec simple-emptydir-pod -c reader-container -- cat /shared-data/message.txt
```

### 🎯 Задание 1.2: emptyDir с памятью (tmpfs)

**1. Создаем emptyDir с использованием памяти:**
```yaml
# pod-emptydir-memory.yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-emptydir-pod
spec:
  containers:
  - name: memory-test-container
    image: alpine:3.18
    command: ["/bin/sh"]
    args: ["-c", "df -h /memory-data && sleep 3600"]
    volumeMounts:
    - name: memory-storage
      mountPath: /memory-data
      
  volumes:
  - name: memory-storage
    emptyDir:
      medium: Memory  # Используем RAM вместо диска
      sizeLimit: 64Mi  # Лимит размера
```

**2. Тестируем:**
```bash
kubectl apply -f pod-emptydir-memory.yaml

# Проверяем что том смонтирован в память
kubectl logs memory-emptydir-pod

# Проверяем доступное место
kubectl exec memory-emptydir-pod -- df -h /memory-data
```

### 🎯 Задание 1.3: Практический пример - кэширование данных

**1. Создаем Pod для кэширования:**
```yaml
# pod-cache-example.yaml
apiVersion: v1
kind: Pod
metadata:
  name: cache-pod
spec:
  containers:
  - name: web-server
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    volumeMounts:
    - name: cache-volume
      mountPath: /var/cache/nginx
      
  - name: cache-cleaner
    image: alpine:3.18
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo 'Cache size:'; du -sh /cache; sleep 30; done"]
    volumeMounts:
    - name: cache-volume
      mountPath: /cache
      
  volumes:
  - name: cache-volume
    emptyDir: {}
```

**2. Тестируем:**
```bash
kubectl apply -f pod-cache-example.yaml

# Генерируем трафик чтобы наполнить кэш
kubectl run test-curl --image=alpine:3.18 --rm -it --restart=Never -- sh
apk add curl
curl http://cache-pod
exit

# Смотрим размер кэша
kubectl logs cache-pod -c cache-cleaner
```

---

## 💾 ЧАСТЬ 2: PersistentVolumeClaims (PVC) и динамическое хранилище

### 🎯 Задание 2.1: Создание первого PVC

**Теория:**
- **PVC** - это запрос на выделение хранилища
- **PV** - фактический ресурс хранилища
- **StorageClass** - определяет тип предоставляемого хранилища

**1. Проверяем доступные StorageClass:**
```bash
kubectl get storageclass
kubectl describe storageclass standard  # В Minikube обычно есть 'standard'
```

**2. Создаем простой PVC:**
```yaml
# pvc-basic.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: basic-pvc
spec:
  accessModes:
    - ReadWriteOnce  # Только одна нода может монтировать для записи
  resources:
    requests:
      storage: 1Gi  # Запрашиваем 1 гигабайт
  # storageClassName: standard  # Можно указать явно, но в Minikube обычно по умолчанию
```

**3. Применяем и проверяем:**
```bash
kubectl apply -f pvc-basic.yaml

# Проверяем PVC
kubectl get pvc
kubectl describe pvc basic-pvc

# Проверяем автоматически созданный PV
kubectl get pv
```

### 🎯 Задание 2.2: Подключение PVC к Pod

**1. Создаем Pod который использует PVC:**
```yaml
# pod-with-pvc.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-pvc
spec:
  containers:
  - name: pvc-user
    image: alpine:3.18
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(date) >> /pvc-data/timestamps.txt; sleep 10; done"]
    volumeMounts:
    - name: pvc-volume
      mountPath: /pvc-data
      
  volumes:
  - name: pvc-volume
    persistentVolumeClaim:
      claimName: basic-pvc  # Используем наш PVC
```

**2. Тестируем постоянное хранение:**
```bash
kubectl apply -f pod-with-pvc.yaml

# Ждем запуска
kubectl get pod pod-with-pvc

# Проверяем что данные пишутся
kubectl exec pod-with-pvc -- cat /pvc-data/timestamps.txt

# Удаляем Pod
kubectl delete pod pod-with-pvc

# Создаем новый Pod с тем же PVC
kubectl apply -f pod-with-pvc.yaml

# Проверяем что данные сохранились!
kubectl exec pod-with-pvc -- cat /pvc-data/timestamps.txt
```

### 🎯 Задание 2.3: Разные access modes

**1. Создаем PVC с ReadWriteMany (если поддерживается):**
```yaml
# pvc-rwx.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-pvc
spec:
  accessModes:
    - ReadWriteMany  # Много Pod могут одновременно писать
  resources:
    requests:
      storage: 2Gi
```

**2. Проверяем поддержку:**
```bash
kubectl apply -f pvc-rwx.yaml

# Смотрим статус PVC
kubectl get pvc shared-pvc

# Если pending - значит не поддерживается
kubectl describe pvc shared-pvc
```

**3. Упражнение: Проверка доступных access modes**
```bash
# Создайте PVC с разными access modes и посмотрите какие работают
kubectl get storageclass standard -o yaml

# Какие access modes поддерживает ваш storage class?
```

---

## 🚀 ЧАСТЬ 3: Практические примеры с томами

### 🎯 Задание 3.1: Веб-приложение с постоянным хранилищем

**1. Создаем PVC для веб-приложения:**
```yaml
# pvc-webapp.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webapp-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

**2. Создаем Deployment с постоянным хранилищем:**
```yaml
# deployment-with-pvc.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-with-storage
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp-storage
  template:
    metadata:
      labels:
        app: webapp-storage
    spec:
      containers:
      - name: webapp
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: web-data
          mountPath: /usr/share/nginx/html
        - name: config-data
          mountPath: /etc/nginx/conf.d
      volumes:
      - name: web-data
        persistentVolumeClaim:
          claimName: webapp-pvc
      - name: config-data
        emptyDir: {}
```

**3. Создаем сервис для доступа:**
```yaml
# service-webapp.yaml
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  type: NodePort
  selector:
    app: webapp-storage
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

**4. Тестируем:**
```bash
kubectl apply -f pvc-webapp.yaml -f deployment-with-pvc.yaml -f service-webapp.yaml

# Проверяем что Pod запустились
kubectl get pods -l app=webapp-storage

# Создаем тестовую страницу
kubectl exec deployment/webapp-with-storage -c webapp -- sh -c "echo '<h1>Hello from Persistent Storage!</h1>' > /usr/share/nginx/html/index.html"

# Проверяем в браузере
minikube service webapp-service --url
```

### 🎯 Задание 3.2: База данных с постоянным хранилищем

**1. Создаем PVC для базы данных:**
```yaml
# pvc-database.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: database-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

**2. Создаем Deployment базы данных:**
```yaml
# deployment-database.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-db
spec:
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_DB
          value: "mydatabase"
        - name: POSTGRES_USER
          value: "myuser"
        - name: POSTGRES_PASSWORD
          value: "mypassword"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: database-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: database-storage
        persistentVolumeClaim:
          claimName: database-pvc
```

**3. Тестируем сохранение данных:**
```bash
kubectl apply -f pvc-database.yaml -f deployment-database.yaml

# Ждем запуска
kubectl get pod -l app=postgres

# Создаем тестовые данные
kubectl exec deployment/postgres-db -c postgres -- psql -U myuser -d mydatabase -c "CREATE TABLE test (id SERIAL, data TEXT);"
kubectl exec deployment/postgres-db -c postgres -- psql -U myuser -d mydatabase -c "INSERT INTO test (data) VALUES ('important data');"

# Проверяем что данные записались
kubectl exec deployment/postgres-db -c postgres -- psql -U myuser -d mydatabase -c "SELECT * FROM test;"

# Удаляем Pod (имитируем сбой)
kubectl delete pod -l app=postgres

# Ждем пересоздания
kubectl get pod -l app=postgres

# Проверяем что данные сохранились!
kubectl exec deployment/postgres-db -c postgres -- psql -U myuser -d mydatabase -c "SELECT * FROM test;"
```

### 🎯 Задание 3.3: Приложение с конфигурацией и данными

**1. Создаем ConfigMap с конфигурацией:**
```yaml
# configmap-app.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.properties: |
    app.name=Storage Practice App
    app.version=1.0.0
    database.url=jdbc:postgresql://postgres-db:5432/mydatabase
    cache.enabled=true
  nginx-custom.conf: |
    server {
        listen 8080;
        server_name localhost;
        root /app/data;
        
        location /status {
            return 200 "active\n";
        }
    }
```

**2. Создаем PVC для данных приложения:**
```yaml
# pvc-app-data.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

**3. Создаем сложное приложение:**
```yaml
# deployment-complex-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complex-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: complex-app
  template:
    metadata:
      labels:
        app: complex-app
    spec:
      containers:
      - name: web-server
        image: nginx:1.25-alpine
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: app-data
          mountPath: /app/data
        - name: app-config
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: nginx-custom.conf
        - name: cache
          mountPath: /var/cache/nginx
          
      - name: data-processor
        image: alpine:3.18
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Processing data at $(date)' >> /app/data/process.log; sleep 30; done"]
        volumeMounts:
        - name: app-data
          mountPath: /app/data
        - name: app-config
          mountPath: /app/config
          
      - name: cache-monitor
        image: alpine:3.18
        command: ["/bin/sh"]
        args: ["-c", "while true; do echo 'Cache usage:' >> /app/data/cache-stats.txt; du -sh /cache >> /app/data/cache-stats.txt; sleep 60; done"]
        volumeMounts:
        - name: app-data
          mountPath: /app/data
        - name: cache
          mountPath: /cache
          
      volumes:
      - name: app-data
        persistentVolumeClaim:
          claimName: app-data-pvc
      - name: app-config
        configMap:
          name: app-config
      - name: cache
        emptyDir:
          sizeLimit: 100Mi
```

**4. Тестируем:**
```bash
kubectl apply -f configmap-app.yaml -f pvc-app-data.yaml -f deployment-complex-app.yaml

# Ждем запуска
kubectl get pod -l app=complex-app

# Проверяем что все контейнеры работают
kubectl logs deployment/complex-app -c web-server
kubectl logs deployment/complex-app -c data-processor
kubectl logs deployment/complex-app -c cache-monitor

# Проверяем данные
kubectl exec deployment/complex-app -c web-server -- ls -la /app/data/
kubectl exec deployment/complex-app -c web-server -- cat /app/data/process.log
```

---

## 🔧 ЧАСТЬ 4: Управление томами и мониторинг

### 🎯 Задание 4.1: Проверка использования томов

**1. Команды для мониторинга:**
```bash
# Показать все PVC
kubectl get pvc

# Показать все PV
kubectl get pv

# Детальная информация о PVC
kubectl describe pvc basic-pvc

# Показать тома в Pod
kubectl describe pod pod-with-pvc

# Проверить использование внутри контейнера
kubectl exec pod-with-pvc -- df -h
```

**2. Упражнение: Анализ использования**
```bash
# Создайте несколько PVC разного размера
kubectl get pv,pvc --sort-by=.spec.capacity.storage

# Какой общий объем хранилища запрошен?
```

### 🎯 Задание 4.2: Освобождение ресурсов

**1. Правильное удаление ресурсов:**
```bash
# Удаляем Pod (тома автоматически отмонтируются)
kubectl delete pod pod-with-pvc

# PVC остается
kubectl get pvc

# Чтобы удалить PVC (и автоматически PV)
kubectl delete pvc basic-pvc

# Проверяем что PV тоже удалился
kubectl get pv
```

**2. Упражнение: Удаление с зависимостями**
```bash
# Что произойдет если удалить PVC который используется Pod?
kubectl delete pvc webapp-pvc

# Смотрим статус Pod
kubectl get pod -l app=webapp-storage

# Как решить эту проблему?
```

### 🎯 Задание 4.3: Резервное копирование данных

**1. Создаем ручную копию данных:**
```bash
# Копируем данные из PVC в локальную директорию
kubectl exec deployment/complex-app -c web-server -- tar czf - /app/data > backup.tar.gz

# Проверяем backup
tar tzf backup.tar.gz

# Восстанавливаем данные (пример)
# kubectl exec deployment/complex-app -c web-server -- tar xzf - -C / < backup.tar.gz
```

---

## 🧪 ЧЕК-ЛИСТ ПРОВЕРКИ ЗНАНИЙ

### Проверьте себя:

**✅ EmptyDir тома:**
- [ ] Могу создать Pod с emptyDir для обмена данными между контейнерами
- [ ] Понимаю разницу между дисковым emptyDir и memory emptyDir
- [ ] Знаю что данные в emptyDir сохраняются при рестарте контейнеров, но не Pod

**✅ PVC и динамическое хранилище:**
- [ ] Могу создать PVC с указанием размера и access modes
- [ ] Понимаю как PVC связывается с PV
- [ ] Умею подключать PVC к Pod
- [ ] Знаю как проверить что данные сохраняются при пересоздании Pod

**✅ Практическое применение:**
- [ ] Могу создать веб-приложение с постоянным хранилищем
- [ ] Могу настроить базу данных с PVC
- [ ] Умею комбинировать разные типы томов в одном Pod
- [ ] Знаю как мониторить использование томов

### 🎯 Финальное упражнение:

**Создайте многоуровневое приложение:**
```bash
# 1. Создайте PVC для базы данных (5Gi)
# 2. Создайте PVC для файлов приложения (2Gi) 
# 3. Разверните базу данных с постоянным хранилищем
# 4. Разверните веб-приложение с:
#    - Постоянным хранилищем для файлов
#    - EmptyDir для кэша
#    - ConfigMap для конфигурации
# 5. Убедитесь что данные сохраняются при перезапуске Pod
```

### 🧹 Очистка:
```bash
# Удаляем все созданные ресурсы
kubectl delete all --all
kubectl delete pvc --all
kubectl delete configmap --all

# Проверяем что все PV освобождены
kubectl get pv

# Останавливаем Minikube
minikube stop
```

---

## 💡 ПОЛЕЗНЫЕ КОМАНДЫ ДЛЯ РАБОТЫ

```bash
# Просмотр ресурсов хранилища
kubectl get pv,pvc,storageclass

# Детальная информация
kubectl describe pvc <pvc-name>
kubectl describe pod <pod-name> | grep -A 10 Volumes

# Проверка внутри Pod
kubectl exec <pod> -- df -h
kubectl exec <pod> -- mount | grep volumes

# Мониторинг событий
kubectl get events --field-selector involvedObject.kind=PersistentVolumeClaim
```

## ⚠️ ВАЖНЫЕ МОМЕНТЫ 

1. **emptyDir** отлично подходит для временных данных и кэша
2. **PVC** нужен для данных которые должны пережить перезапуск Pod
3. **Всегда проверяйте** access modes перед созданием PVC
4. **Не удаляйте PVC** которые используются работающими Pod
5. **Используйте describe** для диагностики проблем с томами

