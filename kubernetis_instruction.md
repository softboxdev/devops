# Установка и развертывание Kubernetes на Ubuntu 24.04 для учебных целей

## 🎯 Варианты установки Kubernetes

### Для разных целей:
- **Minikube** - Локальная разработка (рекомендуется для начала)
- **kubeadm** - Производственный кластер (обучение администрированию)
- **MicroK8s** - Легковесный вариант от Canonical
- **k3s** - Облегченный Kubernetes для edge computing

---

## 🔧 Вариант 1: Minikube (Рекомендуется для обучения)

### Преимущества:
- Простая установка
- Изолированная среда
- Автоматическая настройка
- Подходит для разработки

### Шаг 1: Установка зависимостей

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Docker
sudo apt install -y docker.io

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# Проверка установки Docker
docker --version
```

### Шаг 2: Установка Minikube

```bash
# Скачивание и установка Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Проверка установки
minikube version
```

### Шаг 3: Установка kubectl

```bash
# Скачивание kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Установка
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Проверка
kubectl version --client
```

### Шаг 4: Запуск Minikube

```bash
# Запуск Minikube с драйвером Docker
minikube start --driver=docker

# Проверка статуса
minikube status

# Просмотр информации о кластере
kubectl cluster-info

# Просмотр узлов
kubectl get nodes
```

### Шаг 5: Включение дополнений

```bash
# Включение dashboard
minikube dashboard

# Включение ingress controller
minikube addons enable ingress

# Включение metrics server для autoscaling
minikube addons enable metrics-server

# Список доступных дополнений
minikube addons list
```

---

## 🏗️ Вариант 2: kubeadm (Производственный сценарий)

### Шаг 1: Подготовка системы

```bash
# Отключение swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Настройка hostname (опционально)
sudo hostnamectl set-hostname k8s-master

# Обновление системы
sudo apt update && sudo apt upgrade -y
```

### Шаг 2: Установка Docker

```bash
# Установка зависимостей
sudo apt install -y apt-transport-https ca-certificates curl gnupg

# Добавление Docker репозитория
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Настройка Docker daemon
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Запуск и включение Docker
sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER
```

### Шаг 3: Установка kubeadm, kubelet и kubectl

```bash
# Добавление Kubernetes репозитория
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Установка компонентов
sudo apt update
sudo apt install -y kubelet kubeadm kubectl

# Фиксация версий (предотвращение автоматического обновления)
sudo apt-mark hold kubelet kubeadm kubectl
```

### Шаг 4: Инициализация кластера

```bash
# Инициализация control-plane
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Настройка kubectl для обычного пользователя
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Проверка
kubectl get nodes
```

### Шаг 5: Установка сетевого плагина (CNI)

```bash
# Установка Flannel network plugin
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Альтернатива: Calico
# kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

### Шаг 6: Снятие ограничений с master node (для single-node кластера)

```bash
# Разрешить запуск pod'ов на master node
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

---

## 🐳 Вариант 3: MicroK8s (Самый простой)

### Шаг 1: Установка MicroK8s

```bash
# Установка snap (если не установлен)
sudo apt update
sudo apt install -y snapd

# Установка MicroK8s
sudo snap install microk8s --classic

# Добавление пользователя в группу microk8s
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s
```

### Шаг 2: Настройка и запуск

```bash
# Проверка статуса
microk8s status --wait-ready

# Включение необходимых дополнений
microk8s enable dashboard dns ingress registry storage

# Создание алиасов для удобства
echo "alias kubectl='microk8s kubectl'" >> ~/.bashrc
echo "alias k='microk8s kubectl'" >> ~/.bashrc
source ~/.bashrc

# Проверка
kubectl get nodes
kubectl get all --all-namespaces
```

---

## 🚀 Вариант 4: k3s (Облегченный Kubernetes)

### Шаг 1: Установка k3s

```bash
# Установка k3s
curl -sfL https://get.k3s.io | sh -

# Проверка
sudo k3s kubectl get nodes

# Настройка доступа для пользователя
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config

# Проверка
kubectl get nodes
```

### Шаг 2: Установка дополнительных компонентов

```bash
# Установка Helm (опционально)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Установка ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
```

---

## 🧪 Тестирование установки

### Общие тесты для всех вариантов:

```bash
# 1. Проверка кластера
kubectl cluster-info
kubectl get nodes

# 2. Проверка системных pod'ов
kubectl get pods --all-namespaces

# 3. Создание тестового deployment
kubectl create deployment nginx-test --image=nginx:latest

# 4. Проверка pod'ов
kubectl get pods

# 5. Создание service
kubectl expose deployment nginx-test --port=80 --type=NodePort

# 6. Проверка service
kubectl get services

# 7. Тестирование доступа
curl $(minikube ip):$(kubectl get svc nginx-test -o jsonpath='{.spec.ports[0].nodePort}')

# 8. Очистка тестовых ресурсов
kubectl delete deployment nginx-test
kubectl delete service nginx-test
```

---

## 📊 Сравнение вариантов

| Критерий | Minikube | kubeadm | MicroK8s | k3s |
|----------|----------|---------|-----------|-----|
| **Сложность** | 🟢 Легко | 🔴 Сложно | 🟢 Легко | 🟢 Легко |
| **Ресурсы** | 2GB+ RAM | 2GB+ RAM | 1GB+ RAM | 512MB RAM |
| **Произв. сценарии** | 🟡 Нет | 🟢 Да | 🟡 Частично | 🟡 Частично |
| **Мульти-нода** | 🟡 Ограничено | 🟢 Да | 🟢 Да | 🟢 Да |
| **Лучше для** | Разработка | Продакшен | Разработка/Тесты | Edge/IoT |

---

## 🔧 Дополнительные инструменты

### Установка Helm (пакетный менеджер для Kubernetes)

```bash
# Установка Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Проверка
helm version

# Добавление репозиториев
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Установка k9s (терминальный UI для Kubernetes)

```bash
# Установка k9s
curl -sS https://webinstall.dev/k9s | bash

# Запуск
k9s
```

### Установка Lens IDE

```bash
# Скачивание и установка Lens
wget https://api.k8slens.dev/binaries/Lens-5.5.4-latest.20230313.1.x86_64.AppImage
chmod +x Lens-*.AppImage
./Lens-*.AppImage
```

---

## 🐛 Решение распространенных проблем

### Проблема: Minikube не запускается
```bash
# Очистка и перезапуск
minikube delete
minikube start --driver=docker --force

# Проверка виртуализации
egrep -q 'vmx|svm' /proc/cpuinfo && echo "VT-x/AMD-V supported" || echo "VT-x/AMD-V NOT supported"
```

### Проблема: Pod'ы в статусе Pending
```bash
# Проверка событий
kubectl get events --sort-by=.metadata.creationTimestamp

# Проверка описания pod'а
kubectl describe pod <pod-name>

# Проверка ресурсов узла
kubectl describe node
```

### Проблема: Network issues
```bash
# Перезапуск сетевого плагина
kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### Проблема: Docker permission denied
```bash
# Перелогин после добавления в группу
newgrp docker

# Или перезапуск сессии
sudo su - $USER
```

---

## 📚 Учебные сценарии

### Сценарий 1: Развертывание веб-приложения
```bash
# Создание deployment
kubectl create deployment my-app --image=nginx:latest --replicas=3

# Создание service
kubectl expose deployment my-app --port=80 --type=NodePort

# Получение доступа
minikube service my-app --url
```

### Сценарий 2: Работа с ConfigMap и Secrets
```bash
# Создание ConfigMap
kubectl create configmap app-config --from-literal=APP_COLOR=blue --from-literal=APP_ENV=prod

# Создание Secret
kubectl create secret generic app-secret --from-literal=DB_PASSWORD=secret123

# Проверка
kubectl get configmaps,secrets
```

### Сценарий 3: Мониторинг с Dashboard
```bash
# Запуск dashboard (Minikube)
minikube dashboard

# Или установка dashboard вручную
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl proxy
```

---

## 🎯 Рекомендации для обучения

1. **Начните с Minikube** - самый простой способ начать
2. **Изучите базовые команды kubectl**
3. **Практикуйтесь с разными ресурсами**: Pods, Deployments, Services
4. **Используйте официальную документацию**: https://kubernetes.io/docs/
5. **Присоединитесь к сообществу**: Kubernetes Slack, форумы

**Для Ubuntu 24.04 я рекомендую начать с Minikube** - это самый стабильный и простой вариант для учебных целей! 🚀