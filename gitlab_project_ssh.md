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

### Способ 2: Через GitLab API (альтернативный)

```bash
# Установите необходимые инструменты
sudo apt install -y jq

# Создание проекта через API (замените токен и данные)
GITLAB_URL="http://localhost"
PRIVATE_TOKEN="your_private_token_here"

curl -X POST "$GITLAB_URL/api/v4/projects" \
  -H "PRIVATE-TOKEN: $PRIVATE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-react-app",
    "visibility": "private"
  }'
```

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

### Клонирование пустого проекта

```bash
# Получите SSH URL проекта из GitLab
# Перейдите в ваш проект → Clone → Clone with SSH

# Клонирование проекта
git clone git@localhost:username/my-react-app.git

# Переход в папку проекта
cd my-react-app
```

## 5. Перенос React проекта в GitLab

### Если React проект уже существует

```bash
# Перейдите в папку с существующим React проектом
cd /path/to/your/react-project

# Инициализация Git (если еще не сделано)
git init

# Добавление удаленного репозитория
git remote add origin git@localhost:username/my-react-app.git

# Добавление файлов в коммит
git add .

# Создание первого коммита
git commit -m "Initial commit: React application"

# Отправка кода в GitLab
git push -u origin main

# Если возникает ошибка из-за разницы в ветках:
git push -u origin main:main --force
```

### Если нужно создать новый React проект прямо в репозитории

```bash
# Клонируйте пустой репозиторий
git clone git@localhost:username/my-react-app.git
cd my-react-app

# Создайте React проект
npx create-react-app . --template typescript

# Добавьте и закоммитьте файлы
git add .
git commit -m "Initial React app with TypeScript"
git push -u origin main
```

## 6. Настройка .gitignore для React проекта

Убедитесь, что у вас есть правильный `.gitignore` файл:

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

```yaml
image: node:16

stages:
  - test
  - build

cache:
  paths:
    - node_modules/

before_script:
  - npm install

test:
  stage: test
  script:
    - npm test -- --coverage --watchAll=false

build:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - build/
  only:
    - main
```

## 9. Защита приватных ключей и чувствительных данных

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

## 10. Полезные команды для работы с GitLab

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

## 11. Решение возможных проблем

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