# Создание React проекта на Ubuntu 24.04
Контакты: Telegram @almakonde
soft.box.development@gmail.com


## 1. Установка Node.js и npm

```bash
# Обновление пакетного менеджера
sudo apt update

# Установка Node.js и npm (в Ubuntu 24.04 обычно уже есть актуальные версии)
sudo apt install -y nodejs npm

# Проверка версий
node --version
npm --version

# Установка nvm (рекомендуется для управления версиями Node.js)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash

# Перезагрузите терминал или выполните:
source ~/.bashrc

# Установка последней LTS версии Node.js через nvm
nvm install --lts
nvm use --lts
```

## 2. Создание React проекта

### Способ 1: Использование create-react-app (стандартный)

```bash
# Установка create-react-app глобально
sudo npm install -g create-react-app

# Создание нового проекта
npx create-react-app my-react-app

# Или с использованием глобальной установки
create-react-app my-react-app
```

## 3. Установка дополнительных зависимостей

После создания проекта перейдите в папку проекта:

```bash
cd my-react-app
```

### Базовые зависимости для разработки

```bash
# Установка React Router для навигации
npm install react-router-dom

# Для TypeScript проектов добавьте типы
npm install --save-dev @types/react-router-dom

# Установка популярных UI библиотек
npm install @mui/material @emotion/react @emotion/styled
npm install @mui/icons-material

# Или установка Tailwind CSS
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# Axios для HTTP запросов
npm install axios

# Управление состоянием (Redux Toolkit)
npm install @reduxjs/toolkit react-redux

# Утилиты для разработки
npm install lodash
npm install moment
npm install classnames
```

## 4. Структура проекта после создания

```
my-react-app/
├── public/
│   ├── index.html
│   ├── favicon.ico
│   └── manifest.json
├── src/
│   ├── components/
│   ├── pages/
│   ├── hooks/
│   ├── utils/
│   ├── App.js
│   ├── App.css
│   ├── index.js
│   └── index.css
├── package.json
└── package-lock.json
```

## 5. Запуск проекта

```bash
# Запуск в режиме разработки
npm start

# Сборка для production
npm run build

# Запуск тестов
npm test
```




## Решение возможных проблем

### Проблема с правами при установке пакетов

```bash
# Решение проблем с правами для глобальных пакетов
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### Проблема с портом (если порт 3000 занят)

```bash
# Запуск на другом порте
PORT=3001 npm start

# Или установка переменной окружения
export PORT=3001
npm start
```

### Проблема с совместимостью версий

```bash
# Очистка кэша npm
npm cache clean --force

# Удаление node_modules и повторная установка
rm -rf node_modules
rm package-lock.json
npm install
```

## 10. Полезные команды для разработки

```bash
# Просмотр размера бандла
npm install -g serve
npm run build
serve -s build

# Анализ размера бандла
npm install --save-dev webpack-bundle-analyzer
npx webpack-bundle-analyzer build/static/js/*.js

# Обновление зависимостей
npm outdated
npm update
```

