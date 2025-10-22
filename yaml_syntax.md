### Инструкция по написанию YAML-файлов для GitLab CI/CD

#### Основные понятия:
- **YAML** — формат для описания конфигураций. Использует отступы (пробелы, не табы) и ключевые слова.
- **Pipeline** — процесс автоматизации, состоящий из этапов (stages) и заданий (jobs).
- **Stage** — этап pipeline (например: `build`, `test`, `deploy`). Задания внутри одного этапа выполняются параллельно.
- **Job** — конкретная задача (например: `run_tests`). Содержит команды и параметры.
- **Script** — команды, выполняемые в задании.
- **Image** — Docker-образ, в котором запускается задание.

---

### 1. Деплой в облако (пример: AWS EC2)
```yaml
# Файл .gitlab-ci.yml
stages:
  - deploy # Объявляем этап "deploy"

deploy_to_cloud: # Название задания
  stage: deploy # Привязываем к этапу
  image: alpine:latest # Используем легкий образ Alpine Linux
  before_script:
    - apk add --no-cache openssh-client rsync # Устанавливаем ssh и rsync
  script:
    - chmod 400 $SSH_PRIVATE_KEY # Даем права на приватный ключ
    - rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_PRIVATE_KEY" ./src/ user@ec2-ip:/app/ # Копируем код на сервер
    - ssh -o StrictHostKeyChecking=no -i $SSH_PRIVATE_KEY user@ec2-ip "cd /app && docker-compose up -d" # Запускаем приложение
  only:
    - main # Запускаем только для ветки main
```

#### Расшифровка:
- **before_script** — команды, выполняемые до основного скрипта.
- **$SSH_PRIVATE_KEY** — переменная GitLab CI (хранится в Settings → CI/CD → Variables). Содержит приватный SSH-ключ для доступа к облачному серверу.
- **rsync** — утилита для синхронизации файлов. Параметры:
  - `-a` — архивный режим,
  - `-v` — подробный вывод,
  - `-z` — сжатие данных.
- **StrictHostKeyChecking=no** — отключает подтверждение SSH-хоста.

#### Шаги для настройки:
1. Создайте EC2-инстанс в AWS.
2. Скопируйте публичный ключ в `~/.ssh/authorized_keys` на сервере.
3. Добавьте секретный ключ в переменные GitLab.

---

### 2. Локальный деплой на сервер
```yaml
deploy_to_local:
  stage: deploy
  image: alpine
  script:
    - apk add rsync
    - rsync -avz ./src/ user@local-server-ip:/path/to/app --delete # Копируем файлы с удалением старых
    - ssh user@local-server-ip "sudo systemctl restart my-app.service" # Перезапускаем сервис
  only:
    - main
```

#### Расшифровка:
- **--delete** — удаляет на сервере файлы, которых нет в исходной папке.
- **sudo systemctl restart** — перезапуск systemd-сервиса (требует прав sudo).

#### Альтернатива с Docker:
```yaml
deploy_local_docker:
  stage: deploy
  script:
    - docker build -t my-app . # Собираем образ
    - docker save my-app | ssh user@local-server "docker load" # Передаем образ на сервер
    - ssh user@local-server "docker run -d -p 80:80 my-app" # Запускаем контейнер
```

---

### Общие советы:
1. **Безопасность**:
   - Используйте [GitLab CI Variables](https://docs.gitlab.com/ee/ci/variables/) для хранения секретов.
   - Настройте SSH-ключи без пароля.
2. **Откат при ошибке**:
   Добавьте шаг проверки после деплоя:
   ```yaml
   - curl -f http://server-health-check || exit 1
   ```
3. **Теги runner**:
   Если используете специфические runner, укажите теги:
   ```yaml
   tags:
     - local
     - production
   ```
4. **Артефакты**:
   Сохраняйте собранные файлы между этапами:
   ```yaml
   build:
     script: npm run build
     artifacts:
       paths:
         - dist/
   ```

Пример полного файла с двумя этапами:
```yaml
stages:
  - build
  - deploy

build_job:
  stage: build
  script: 
    - echo "Собираем приложение..."
    - make build

deploy_job:
  stage: deploy
  script:
    - echo "Деплоим..."
    - ./deploy.sh
  dependencies:
    - build_job # Зависит от артефактов build_job
```
# Подробная расшифровка синтаксиса YAML для GitLab CI/CD

## Базовая структура YAML

### 1. **Ключевые слова верхнего уровня**

```yaml
# Комментарий - строка, начинающаяся с #
default: # Настройки по умолчанию для всех заданий
  image: alpine:latest # Образ Docker по умолчанию
  before_script: # Скрипты, выполняемые перед каждым заданием
    - echo "Начало выполнения"

variables: # Глобальные переменные pipeline
  DEPLOY_ENV: "production" # Переменная со значением
  APP_VERSION: "1.0.0"

stages: # Определение последовательности этапов
  - build    # Этап 1: Сборка
  - test     # Этап 2: Тестирование  
  - deploy   # Этап 3: Деплой

include: # Включение внешних конфигураций
  - local: '/templates/.gitlab-ci.yml' # Локальный файл
  - remote: 'https://example.com/ci.yml' # Удаленный URL
  - template: 'Auto-DevOps.gitlab-ci.yml' # Шаблон GitLab

workflow: # Управление поведением pipeline
  rules: # Правила запуска pipeline
    - if: $CI_COMMIT_BRANCH == "main"

```

### 2. **Структура задания (Job)**

```yaml
job_name: # Уникальное имя задания (латинские буквы, цифры, _)
  stage: test # Принадлежность к этапу (обязательно)
  image: node:16 # Docker-образ для выполнения задания
  services: # Вспомогательные сервисы (базы данных и т.д.)
    - postgres:13
    - redis:latest
  
  variables: # Локальные переменные задания
    NODE_ENV: "test"
    DATABASE_URL: "postgresql://user:pass@postgres/db"
  
  before_script: # Команды перед основным скриптом
    - npm install
    - echo "Подготовка к тестам"
  
  script: # Основные команды задания (обязательно)
    - npm run test:unit
    - npm run test:integration
    - echo "Тестирование завершено"
  
  after_script: # Команды после основного скрипта
    - echo "Очистка временных файлов"
    - rm -rf ./tmp
  
  allow_failure: false # Запрет падения pipeline при ошибке
  when: on_success # Когда запускать: on_success, always, manual, delayed
  tags: # Теги для выбора runner
    - docker
    - linux
```

### 3. **Правила выполнения (Rules)**

```yaml
job_with_rules:
  script: echo "Задание с условиями"
  rules: # Условия выполнения задания
    - if: $CI_COMMIT_BRANCH == "main" # Если ветка main
      when: always # Выполнять всегда
      allow_failure: false # Не разрешать падение
    
    - if: $CI_COMMIT_BRANCH =~ /^feature/ # Регулярное выражение
      when: manual # Ручной запуск
      variables: # Установка переменных для этого условия
        DEPLOY_ENV: "staging"
    
    - if: $CI_COMMIT_TAG # Если есть тег
      when: on_success
    
    - when: always # Запасное условие
```

### 4. **Кэширование и артефакты**

```yaml
cache: # Кэширование между заданиями
  key: ${CI_COMMIT_REF_SLUG} # Ключ кэша (по ветке)
  paths: # Пути для кэширования
    - node_modules/
    - .npm/
  policy: pull-push # Политика: pull, push, pull-push

build_job:
  stage: build
  script: 
    - npm install
    - npm run build
  artifacts: # Артефакты - файлы для передачи между этапами
    name: "build-$CI_COMMIT_REF_NAME" # Имя архива
    paths: # Пути к файлам
      - dist/
      - build/
    exclude: # Исключения
      - "*.tmp"
    expire_in: 1 week # Время хранения
    when: on_success # Когда сохранять: on_success, always, on_failure
    reports: # Специальные отчеты
      junit: reports/junit.xml # Отчеты тестов
      coverage_report: # Отчет покрытия
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
```

### 5. **Окружения и деплой**

```yaml
deploy_production:
  stage: deploy
  script:
    - ./deploy.sh production
  environment: # Окружение для деплоя
    name: production # Имя окружения
    url: https://myapp.com # URL приложения
    action: start # Действие: start, prepare, stop
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  resource_group: production # Группа ресурсов (последовательный деплой)

deploy_review:
  stage: deploy
  script:
    - ./deploy_review.sh
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_ENVIRONMENT_SLUG.example.com
    on_stop: stop_review # Задание для остановки окружения
  auto_stop_in: 1 day # Автоостановка через 1 день

stop_review: # Задание для остановки окружения
  stage: deploy
  script:
    - ./stop_review.sh
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  when: manual # Только ручной запуск
  rules:
    - if: $CI_COMMIT_BRANCH =~ /^feature/
      when: manual
```

### 6. **Расширенные возможности**

```yaml
.anchor_template: &job_settings # Якорь для повторного использования
  image: alpine
  tags: 
    - docker
  before_script:
    - echo "Общие настройки"

job1:
  <<: *job_settings # Слияние с якорем
  script: echo "Задание 1"

job2:
  <<: *job_settings
  script: echo "Задание 2"

parallel_job:
  stage: test
  script: ./test.sh
  parallel: 5 # Параллельное выполнение 5 копий задания
  variables: # Разные переменные для каждой копии
    TEST_SUITE: 
      - "unit"
      - "integration" 
      - "e2e"
      - "performance"
      - "security"

matrix_job: # Матрица заданий (GitLab 13.5+)
  stage: test
  script: ./test.sh $VERSION $OS
  parallel:
    matrix:
      - VERSION: ["12", "14", "16"]
        OS: ["alpine", "ubuntu"]
```

### 7. **Триггеры и зависимости**

```yaml
trigger_build:
  stage: deploy
  trigger: # Запуск другого pipeline
    project: my-group/my-project
    branch: main
    strategy: depend # Зависимость от дочернего pipeline

parent_job:
  stage: test
  script: echo "Родительское задание"
  needs: # Зависимости между заданиями (обход порядка stages)
    - job: build_job
      artifacts: true
    - project: 'my-group/dependency'
      job: 'build'
      ref: 'main'
      artifacts: true

child_pipeline:
  stage: test
  trigger:
    include: child.yml # Включение дочернего pipeline
    strategy: depend
```

### 8. **Полный пример с комментариями**

```yaml
# Глобальные настройки
default:
  image: node:16-alpine
  before_script:
    - apk add --no-cache git openssh-client
    - npm ci --cache .npm --prefer-offline

variables:
  NODE_ENV: "test"
  DOCKER_HOST: "tcp://docker:2375"

stages:
  - prepare
  - build
  - test
  - deploy

# Этап 1: Подготовка
install_dependencies:
  stage: prepare
  script:
    - npm ci
  artifacts:
    paths:
      - node_modules/
    expire_in: 1 hour
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
    policy: pull-push

# Этап 2: Сборка
build_app:
  stage: build
  script:
    - npm run build
    - npm run bundle
  artifacts:
    name: "bundle-${CI_COMMIT_SHORT_SHA}"
    paths:
      - dist/
      - build/
    expire_in: 1 week
  dependencies:
    - install_dependencies

# Этап 3: Тестирование
unit_tests:
  stage: test
  script:
    - npm run test:unit
  artifacts:
    reports:
      junit: reports/junit.xml
    expire_in: 1 week

integration_tests:
  stage: test
  script:
    - npm run test:integration
  needs: ["build_app"] # Зависит от build_app, не ждет stage

e2e_tests:
  stage: test
  script:
    - npm run test:e2e
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# Этап 4: Деплой
deploy_staging:
  stage: deploy
  image: alpine:latest
  before_script:
    - apk add --no-cache openssh-client rsync
  script:
    - chmod 400 "$SSH_PRIVATE_KEY"
    - rsync -avz -e "ssh -o StrictHostKeyChecking=no -i $SSH_PRIVATE_KEY" ./dist/ deploy@server:/app/
    - ssh -i "$SSH_PRIVATE_KEY" deploy@server "sudo systemctl restart myapp"
  environment:
    name: staging
    url: https://staging.myapp.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  resource_group: staging

deploy_production:
  stage: deploy
  script:
    - ./deploy_to_prod.sh
  environment:
    name: production
    url: https://myapp.com
  rules:
    - if: $CI_COMMIT_TAG
      when: manual
  resource_group: production
```

## Ключевые переменные GitLab CI/CD

```yaml
# Предопределенные переменные (доступны автоматически)
example:
  script:
    - echo "Ветка: $CI_COMMIT_REF_NAME" # Имя ветки/тега
    - echo "SHA коммита: $CI_COMMIT_SHA" # Хэш коммита
    - echo "Проект: $CI_PROJECT_PATH" # Путь к проекту
    - echo "Pipeline ID: $CI_PIPELINE_ID" # ID pipeline
    - echo "Задание ID: $CI_JOB_ID" # ID задания
    - echo "Сервер: $CI_SERVER_HOST" # URL GitLab
```

 