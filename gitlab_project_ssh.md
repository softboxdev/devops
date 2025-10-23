# Создание пустого проекта в GitLab и настройка SSH ключей

## 1. Создание SSH ключей на Ubuntu

### Генерация SSH ключа

```bash
# Генерация нового SSH ключа (замените email на ваш)
ssh-keygen -t ed25519 -C "your.email@example.com"

# Или для совместимости с более старыми системами:
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"
```

Во время генерации укажите:
- **File path**: Нажмите Enter для расположения по умолчанию (`/home/username/.ssh/id_ed25519`)
- **Passphrase**: Придумайте надежную парольную фразу (рекомендуется)

### Проверка сгенерированных ключей

```bash
# Просмотр публичного ключа
cat ~/.ssh/id_ed25519.pub

# Просмотр приватного ключа (будьте осторожны!)
cat ~/.ssh/id_ed25519
```

### Добавление ключа в SSH-агент

```bash
# Запуск SSH-агента
eval "$(ssh-agent -s)"

# Добавление приватного ключа
ssh-add ~/.ssh/id_ed25519
```

## 2. Создание пустого проекта в GitLab

### Способ 1: Через веб-интерфейс GitLab

1. **Войдите в GitLab** по адресу `http://localhost`
2. **Создайте новый проект**:
   - Нажмите "New project"
   - Выберите "Create blank project"
   - Заполните детали проекта:
     - **Project name**: `my-react-app`
     - **Project URL**: оставьте `http://localhost/username/my-react-app`
     - **Visibility Level**: `Private` (рекомендуется)
   - Нажмите "Create project"


## 3. Добавление SSH ключа в GitLab

### Копирование публичного ключа

```bash
# Копирование публичного ключа в буфер обмена
xclip -sel clip < ~/.ssh/id_ed25519.pub

# Или просмотр для ручного копирования
cat ~/.ssh/id_ed25519.pub
```

### Добавление ключа в GitLab через веб-интерфейс

1. **Перейдите в настройки SSH ключей**:
   - Кликните на ваш аватар в правом верхнем углу
   - Выберите "Edit profile"
   - В левом меню выберите "SSH Keys"

2. **Добавьте ключ**:
   - Вставьте содержимое публичного ключа в поле "Key"
   - Укажите название (например, "My Ubuntu Laptop")
   - Нажмите "Add key"

### Проверка подключения

```bash
# Проверка подключения к GitLab
ssh -T git@localhost
```

Вы должны увидеть сообщение: `Welcome to GitLab, @username!`

## 4. Настройка Git и подключение к проекту

### Настройка глобальных параметров Git

```bash
# Настройка имени пользователя и email
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Настройка ветки по умолчанию
git config --global init.defaultBranch main

# Сохранение учетных данных (опционально)
git config --global credential.helper store
```


## 5. Залить React проект в GitLab
См. инструкцию по созданию https://github.com/softboxdev/devops/blob/dev/basic_app.md

```bash
# Перейдите в папку с существующим React проектом
cd /path/to/your/react-project

# Инициализация Git (если еще не сделано)
git init

# Добавление удаленного репозитория
git remote add origin git@localhost:username/my-react-app.git(адресвашегорепозитория)

# Добавление файлов в коммит
git add .

# Создание первого коммита
git commit -m "Initial commit: React application"

# Отправка кода в GitLab
git push -u origin main

# Если возникает ошибка из-за разницы в ветках:
git push -u origin main:main --force
```


## 6. Настройка .gitignore для React проекта

Убедитесь, что у вас есть правильный `.gitignore` файл в корне проекта:

```bash
# Создайте .gitignore если его нет
cat > .gitignore << EOF
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Production build
build/
dist/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
logs
*.log

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/

# Dependency directories
jspm_packages/

# Optional npm cache directory
.npm

# Optional REPL history
.node_repl_history

# Output of 'npm pack'
*.tgz

# Yarn Integrity file
.yarn-integrity
EOF
```

## 7. Настройка CI/CD 

Создайте файл `.gitlab-ci.yml` в корне проекта:
# Самый простой вариант деплоя React на localhost без nginx

## 1. Простой .gitlab-ci.yml

```yaml
image: node:16

stages:
  - build
  - deploy

cache:
  paths:
    - node_modules/

build:
  stage: build
  script:
    - npm install
    - npm run build
  artifacts:
    paths:
      - build/
    expire_in: 1 hour
  only:
    - main

deploy_local:
  stage: deploy
  script:
    - echo "Деплой React приложения на localhost:3001"
    - cp -r build/* /tmp/react-app/
    - echo "✅ Приложение успешно размещено по адресу: http://localhost:3001"
  only:
    - main
  tags:
    - local
```

## 2. Упрощенный вариант с прямым сервингом

```yaml
image: node:16

stages:
  - deploy

deploy_local:
  stage: deploy
  script:
    - echo "Установка зависимостей и запуск React приложения..."
    - npm install
    - npm install -g serve
    - echo "🚀 Запуск приложения на порту 3001..."
    - nohup serve -s build -l 3001 > /dev/null 2>&1 &
    - echo "✅ Приложение доступно по адресу: http://localhost:3001"
  only:
    - main
  tags:
    - local
```


## 3. Самый минимальный вариант

```yaml
deploy_react:
  image: node:16
  script:
    - npm install
    - npm run build
    - npm install -g serve
    - pkill -f "serve.*3001" || true
    - nohup serve -s build -l 3001 &
    - echo "React app deployed to http://localhost:3001"
  only:
    - main
  tags:
    - local
```

## 4. Настройка сервера для деплоя

### Подготовка директории:

```bash
# Создаем директорию для приложения
sudo mkdir -p /tmp/react-app
sudo chmod 755 /tmp/react-app

# Или в домашней директории
mkdir -p ~/my-react-apps
```

### Ручной запуск приложения (для тестирования):

```bash
# Переходим в папку с собранным приложением
cd build

# Запускаем с помощью serve
npx serve -s . -l 3001

# Или с помощью Python
python -m http.server 3001

# Или с помощью PHP
php -S localhost:3001
```



## 5. Вариант с использованием PM2 для управления процессом

```yaml
image: node:16

stages:
  - deploy

deploy_react:
  stage: deploy
  script:
    - npm install
    - npm run build
    - npm install -g pm2 serve
    - pm2 stop react-app || true
    - pm2 delete react-app || true
    - pm2 serve build 3001 --name react-app --spa
    - pm2 save
    - pm2 startup
    - echo "✅ React app deployed with PM2: http://localhost:3001"
  only:
    - main
  tags:
    - local
```

## 6. Простой вариант с копированием и запуском

```yaml
deploy_simple:
  image: node:16
  script:
    - echo "🔨 Building React app..."
    - npm install
    - npm run build
    
    - echo "📁 Copying files to deployment directory..."
    - rm -rf /tmp/react-app-deploy
    - mkdir -p /tmp/react-app-deploy
    - cp -r build/* /tmp/react-app-deploy/
    
    - echo "🌐 Starting web server..."
    - cd /tmp/react-app-deploy
    - nohup python3 -m http.server 3001 &> server.log &
    
    - echo "🎉 DEPLOYMENT COMPLETE!"
    - echo "📍 Your app is available at: http://localhost:3001"
    - echo "📋 Server logs: /tmp/react-app-deploy/server.log"
  only:
    - main
  tags:
    - local
```

## 7. Проверка деплоя

После запуска пайплайна проверьте:

```bash
# Проверьте что приложение запущено
curl -I http://localhost:3001

# Или откройте в браузере
xdg-open http://localhost:3001

# Посмотрите логи если нужно
cat /tmp/react-app-deploy/server.log
```

## 10. Остановка приложения (если нужно)

```bash
# Найти и остановить процесс на порту 3001
sudo lsof -ti:3001 | xargs kill -9

# Или остановить все serve процессы
pkill -f "serve.*3001"
```

## Самый рекомендуемый простой вариант:

```yaml
deploy_react_local:
  image: node:16
  script:
    - npm install
    - npm run build
    - npm install -g serve
    - pkill -f "serve.*3001" || true
    - nohup serve -s build -l 3001 &> /tmp/react-app.log &
    - echo "✅ React app deployed to: http://localhost:3001"
  only:
    - main
  tags:
    - local
```




## 8. Защита приватных ключей и чувствительных данных

### Важные предупреждения:

- **НИКОГДА не коммитьте приватные SSH ключи** в репозиторий
- **НИКОГДА не добавляйте** файлы с расширениями `.pem`, `.key`, `id_rsa` и т.д.
- Используйте `.gitignore` для защиты чувствительных файлов

### Если нужно хранить конфигурационные файлы:

```bash
# Создайте файл для примеров конфигурации
cp .env.example .env

# Добавьте .env в .gitignore
echo ".env" >> .gitignore
```

## 9. Полезные команды для работы с GitLab

### Проверка статуса

```bash
# Проверка статуса репозитория
git status

# Просмотр удаленных репозиториев
git remote -v

# Просмотр истории коммитов
git log --oneline
```

### Обновление репозитория

```bash
# Получение последних изменений
git pull origin main

# Принудительный push (используйте с осторожностью)
git push origin main --force
```

### Работа с ветками

```bash
# Создание новой ветки
git checkout -b feature/new-feature

# Отправка ветки на сервер
git push -u origin feature/new-feature
```

## 10. Решение возможных проблем

### Проблема с SSH подключением

```bash
# Проверка SSH подключения
ssh -vT git@localhost

# Перезапуск SSH-агента
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Проблема с правами доступа

```bash
# Проверка прав на SSH ключи
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

### Проблема с push в репозиторий

```bash
# Если репозиторий не пустой
git pull origin main --allow-unrelated-histories
git push origin main
```

Вы можете продолжать разработку и использовать все возможности GitLab CI/CD.