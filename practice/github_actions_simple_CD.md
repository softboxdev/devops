Простейшая инструкция по деплою React-приложения на Yandex Cloud с использованием минимального YAML-файла для GitHub Actions.

---

## 📁 Часть 1: Структура проекта

Ваш проект `my-react-app` должен выглядеть так:

```
my-react-app/
├── .github/
│   └── workflows/
│       └── deploy.yml          # 👈 ЭТОТ ФАЙЛ НАМ НУЖЕН
├── build/                      # (появится после сборки)
├── public/
├── src/
├── package.json
└── ...
```

---

## 🔧 Часть 2: Самый простой YAML-файл

Создайте файл `.github/workflows/deploy.yml` в корне вашего проекта:

```bash
mkdir -p .github/workflows
nano .github/workflows/deploy.yml
```

Вставьте этот **минимальный конфиг**:

```yaml
name: Deploy to Yandex Cloud

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      
      - run: npm ci
      - run: npm run build
      
      - name: Deploy via SSH
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.SERVER_IP }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          source: "build/"
          target: "/var/www/my-react-app/"
          strip_components: 1
      
      - name: Reload Nginx
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SERVER_IP }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            sudo systemctl reload nginx
```

---

## 🔐 Часть 3: Секреты в GitHub

В репозитории на GitHub:

**Settings → Secrets and variables → Actions → New repository secret**

Добавьте 3 секрета:

| Secret name | Откуда взять |
|-------------|--------------|
| `SERVER_IP` | Публичный IP вашей ВМ в Yandex Cloud |
| `SERVER_USER` | `ubuntu` (или ваш логин) |
| `SSH_PRIVATE_KEY` | Содержимое `~/.ssh/id_rsa` (приватный ключ) |

---

## 🖥️ Часть 4: Настройка сервера (один раз)

Подключитесь к ВМ и выполните:

```bash
# Установка Nginx
sudo apt update
sudo apt install -y nginx

# Создание папки для сайта
sudo mkdir -p /var/www/my-react-app
sudo chown -R $USER:$USER /var/www/my-react-app

# Настройка Nginx
sudo tee /etc/nginx/sites-available/my-react-app > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;
    root /var/www/my-react-app;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

# Включаем сайт
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/my-react-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## 🚀 Часть 5: Запуск деплоя

```bash
# Заливаем код на GitHub
git add .
git commit -m "Add deploy workflow"
git push origin main
```

Через 2-3 минуты сайт будет доступен по адресу:  
`http://ВАШ_IP_ВМ`

---

## 📦 Ещё более простой вариант (без SSH-ключа)

Если не хотите возиться с SSH-ключами, используйте **Yandex Cloud CLI**:

```yaml
name: Deploy to Yandex Cloud

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      
      - run: npm ci
      - run: npm run build
      
      - name: Install Yandex CLI
        uses: yandex-cloud/actions/yc-install@v1
      
      - name: Copy files to VM
        run: |
          yc scp --ssh-key <(echo "${{ secrets.SSH_PRIVATE_KEY }}") \
            -r ./build/* ${{ secrets.SERVER_USER }}@${{ secrets.SERVER_IP }}:/var/www/my-react-app/
```

---

## ✅ Минимальный чеклист

- [ ] Создана ВМ в Yandex Cloud с публичным IP
- [ ] Установлен Nginx на ВМ
- [ ] Файл `.github/workflows/deploy.yml` создан
- [ ] SSH-ключ добавлен в GitHub Secrets
- [ ] Сделан `git push`

---

## ❗ Частая ошибка

**Ошибка:** `Permission denied (publickey)`  
**Решение:** Убедитесь, что публичный ключ добавлен на ВМ:

```bash
# На ВМ
echo "ваш_публичный_ключ" >> ~/.ssh/authorized_keys
```
