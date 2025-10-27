# Руководство по настройке CI/CD в GitLab для учебного проекта

## Архитектура решения


```
GitLab (на VM) → CI/CD Pipeline → Тестовый сервер (на этой же VM)
```

## Предварительные настройки

### 1. Настройка GitLab Runner

```bash
# Установка GitLab Runner
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install gitlab-runner

# Добавление пользователя gitlab-runner в группу docker
sudo usermod -aG docker gitlab-runner
```

### 2. Регистрация Runner в GitLab

```bash
sudo gitlab-runner register
```

В процессе регистрации укажите:

- **GitLab instance URL**: `http://localhost`
- **Registration token**: 
  - Перейдите в GitLab → Admin → Overview → Runners
  - Или в проекте: Settings → CI/CD → Runners
- **Description**: `local-runner`
- **Tags**: `local, test`
- **Executor**: `shell` (для простоты) или `docker`

### 3. Проверка Runner

```bash
sudo gitlab-runner verify
sudo gitlab-runner status
```

## Настройка тестового окружения

### Создание тестовой директории

```bash
sudo mkdir -p /var/www/test-project
sudo chown -R $USER:$USER /var/www/test-project
```

### Пример простого веб-приложения

Создайте тестовый проект в GitLab:

```bash
mkdir my-test-project
cd my-test-project
git init
```

Создайте файл `index.html`:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Test Project</title>
</head>
<body>
    <h1>Hello from CI/CD Pipeline!</h1>
    <p>Version: <span id="version">1.0.0</span></p>
    <p>Build date: <span id="build-date">##BUILD_DATE##</span></p>
</body>
</html>
```

Создайте файл `deploy.sh`:
```bash
#!/bin/bash
echo "Deploying to test server..."
cp -r * /var/www/test-project/
echo "Deployment completed!"
```

Сделайте скрипт исполняемым:
```bash
chmod +x deploy.sh
```

## Настройка CI/CD Pipeline

### Создание файла `.gitlab-ci.yml`

#  .gitlab-ci.yml

```yaml
# .gitlab-ci.yml - это основной файл конфигурации для GitLab CI/CD
# GitLab автоматически обнаруживает и выполняет этот файл при каждом пуше в репозиторий

# Блок stages определяет последовательность этапов выполнения pipeline
stages:
  - test    # Первая стадия - тестирование кода
  - build   # Вторая стадия - сборка приложения
  - deploy  # Третья стадия - развертывание на сервер

# Блок variables задает переменные окружения, доступные во всех job'ах
variables:
  # DEPLOY_PATH - пользовательская переменная, содержащая путь для деплоя
  DEPLOY_PATH: "/var/www/test-project"

# Блок before_script содержит команды, которые выполняются ПЕРЕД каждым job'ом
before_script:
  # Выводим сообщение в лог с указанием имени ветки
  # $CI_COMMIT_REF_NAME - встроенная переменная GitLab с именем ветки/тега
  - echo "Starting pipeline for $CI_COMMIT_REF_NAME"

# Job "test" - задача тестирования
test:
  # stage указывает к какой стадии принадлежит этот job
  stage: test  # Этот job выполняется на стадии "test"
  
  # script содержит последовательность команд, выполняемых в этом job'е
  script:
    # Вывод информационного сообщения в лог
    - echo "Running tests..."
    
    # Сообщение о начале проверки HTML файлов
    - echo "Linting HTML files..."
    
    # Команда find ищет все .html файлы и выполняет для каждого команду echo
    # {} заменяется на имя найденного файла
    # -exec выполняет команду для каждого найденного файла
    - find . -name "*.html" -exec echo "Validating {}" \;
    
    # Финальное сообщение об успешном завершении тестов
    - echo "All tests passed!"
  
  # only определяет условия, когда этот job должен выполняться
  only:
    - main    # Выполнять только для ветки main
    - develop # И для ветки develop

# Job "build" - задача сборки приложения
build:
  stage: build  # Принадлежит стадии "build"
  
  script:
    - echo "Building application..."
    
    # export создает переменную окружения BUILD_DATE с текущей датой и временем
    # date +"%Y-%m-%d %H:%M:%S" - форматирование даты: ГГГГ-ММ-ДД ЧЧ:ММ:СС
    - export BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")
    
    # sed - команда для потокового редактирования текста
    # -i - редактирование файла "на месте" (in-place)
    # "s/##BUILD_DATE##/$BUILD_DATE/g" - заменить все вхождения ##BUILD_DATE## на значение переменной
    # g - глобальная замена (все вхождения в файле)
    - sed -i "s/##BUILD_DATE##/$BUILD_DATE/g" index.html
    
    # Вывод сообщения о завершении сборки с датой
    - echo "Build completed: $BUILD_DATE"
  
  # artifacts определяет файлы, которые сохраняются после выполнения job'а
  artifacts:
    # paths - список путей к файлам/директориям для сохранения
    paths:
      - ./  # Сохранить всю текущую директорию (включая измененный index.html)
    
    # expire_in - время жизни артефактов (после этого они удаляются)
    expire_in: 1 hour  # Удалить через 1 час
  
  only:
    - main
    - develop

# Job "deploy_to_test" - задача развертывания на тестовый сервер
deploy_to_test:
  stage: deploy  # Стадия развертывания
  
  script:
    - echo "Deploying to test server..."
    
    # sudo - выполнение команды с правами суперпользователя
    # cp -r * - рекурсивное копирование всех файлов из текущей директории
    # $DEPLOY_PATH - использование переменной, определенной выше
    - sudo cp -r * $DEPLOY_PATH/
    
    - echo "Deployment completed successfully!"
    
    # Сообщение с URL, где доступно приложение
    - echo "Application available at: http://localhost/test-project"
  
  # environment определяет окружение для этого job'а
  environment:
    name: test  # Название окружения (отображается в GitLab UI)
    url: http://localhost/test-project  # URL окружения (для быстрого доступа из GitLab)
  
  only:
    - main  # Выполнять ТОЛЬКО для ветки main
  
  # tags определяет, какой runner должен выполнять этот job
  tags:
    - local  # Выполнять только на runner'ах с тегом "local"

# Job "deploy_to_develop" - задача развертывания на develop окружение
deploy_to_develop:
  stage: deploy
  
  script:
    - echo "Deploying to develop server..."
    
    # mkdir -p - создание директории (с родительскими директориями при необходимости)
    - sudo mkdir -p /var/www/develop-project
    
    # Копирование файлов в develop директорию
    - sudo cp -r * /var/www/develop-project/
    
    - echo "Develop deployment completed!"
  
  environment:
    name: develop  # Отдельное окружение для develop
    url: http://localhost/develop-project
  
  only:
    - develop  # Выполнять ТОЛЬКО для ветки develop
  
  tags:
    - local  # Тоже выполняется на локальных runner'ах
```

## Как это работает поэтапно:

### 1. **Запуск Pipeline**
- При пуше в ветки `main` или `develop` GitLab автоматически обнаруживает `.gitlab-ci.yml`
- Создается новый pipeline с определенными стадиями

### 2. **Стадия Test**
- Выполняется job `test`
- Запускаются "тесты" (в данном случае демонстрационные)
- Проверяются HTML файлы

### 3. **Стадия Build**
- Выполняется job `build`
- В файл `index.html` подставляется текущая дата сборки
- Создаются артефакты - все файлы проекта сохраняются для следующих стадий

### 4. **Стадия Deploy**
- В зависимости от ветки выполняются разные job'ы:
  - `main` → `deploy_to_test` (на тестовый сервер)
  - `develop` → `deploy_to_develop` (на develop сервер)
- Файлы копируются в соответствующие директории на сервере

### 5. **Результат**
- Приложение доступно по соответствующему URL
- В GitLab UI можно видеть статус каждого job'а
- Можно просматривать логи выполнения каждой команды

## Важные особенности:

- **Порядок выполнения**: Стадии выполняются последовательно, job'ы внутри стадии могут выполняться параллельно
- **Артефакты**: Файлы из стадии `build` автоматически передаются в стадию `deploy`
- **Условное выполнение**: Job'ы выполняются только для указанных веток
- **Тэгирование**: Job'ы выполняются только на runner'ах с определенными тэгами
- **Окружения**: Разные окружения для тестирования и разработки
