
---

# Практическая работа: Анализ приложения на соответствие DevOps

## Цели работы
1. Научиться проводить аудит существующего приложения по критериям DevOps.
2. Выявить недостатки в автоматизации, конфигурации, развёртывании и мониторинге.
3. Предложить практические улучшения с использованием инструментов DevOps.
4. Оценить зрелость приложения по модели **CALMS** (Culture, Automation, Lean, Measurement, Sharing) и **DORA** (частотность релизов, время выполнения изменений, MTTR, процент неудачных изменений).

## Исходные данные
- Ubuntu 24.04 (свежая установка или VM).
- Тестовое приложение: **Простой To-Do менеджер на Node.js + Express + SQLite** (намеренно содержит антипаттерны с точки зрения DevOps).
- Никаких CI/CD, контейнеризации, мониторинга и инфраструктуры как код нет.

---

## Подготовка окружения

Выполните в терминале:

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка Node.js 20.x и npm
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs git sqlite3 curl

# Проверка версий
node --version   # ожидается v20.x
npm --version
sqlite3 --version

# Клонирование тестового приложения (создадим его прямо на месте)
mkdir -p ~/devops-lab && cd ~/devops-lab
```

Создайте приложение с проблемами:

```bash
# Создаём структуру проекта
mkdir todo-app && cd todo-app
npm init -y
npm install express sqlite3

# Создаём файл app.js с намеренными проблемами
cat > app.js << 'EOF'
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

// Проблема 1: База данных в рабочей директории, не в volumes/не отдельно
const db = new sqlite3.Database('./todo.db');

db.run(`CREATE TABLE IF NOT EXISTS todos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task TEXT NOT NULL,
  completed BOOLEAN DEFAULT 0
)`);

app.use(express.json());
app.use(express.static('public'));

// API
app.get('/todos', (req, res) => {
  db.all('SELECT * FROM todos', (err, rows) => {
    if (err) return res.status(500).json({error: err.message});
    res.json(rows);
  });
});

app.post('/todos', (req, res) => {
  const { task } = req.body;
  if (!task) return res.status(400).json({error: 'Task required'});
  db.run('INSERT INTO todos (task) VALUES (?)', [task], function(err) {
    if (err) return res.status(500).json({error: err.message});
    res.json({id: this.lastID});
  });
});

app.delete('/todos/:id', (req, res) => {
  const { id } = req.params;
  db.run('DELETE FROM todos WHERE id = ?', id, function(err) {
    if (err) return res.status(500).json({error: err.message});
    res.json({deleted: this.changes});
  });
});

// Проблема 2: Нет graceful shutdown, нет логирования в структурированном виде
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
EOF

# Создаём простой HTML фронт
mkdir public
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Todo App</title></head>
<body>
<h1>Todo List</h1>
<input type="text" id="task" placeholder="New task">
<button onclick="addTodo()">Add</button>
<ul id="list"></ul>
<script>
async function loadTodos() {
  const res = await fetch('/todos');
  const todos = await res.json();
  const list = document.getElementById('list');
  list.innerHTML = todos.map(t => `<li>${t.task} <button onclick="deleteTodo(${t.id})">X</button></li>`).join('');
}
async function addTodo() {
  const task = document.getElementById('task').value;
  await fetch('/todos', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({task})});
  loadTodos();
}
async function deleteTodo(id) {
  await fetch(`/todos/${id}`, {method:'DELETE'});
  loadTodos();
}
loadTodos();
</script>
</body>
</html>
EOF

# Проблема 3: Отсутствие .gitignore, переменных окружения, тестов
echo "Запустите: node app.js"
```

---

## Часть 1. Первичный анализ приложения (ручной аудит)

### Задание 1.1. Запустите приложение и оцените процесс развёртывания

```bash
cd ~/devops-lab/todo-app
node app.js
```
Откройте браузер: `http://localhost:3000`

**Вопросы для анализа (письменно ответьте):**
1. Сколько ручных действий потребовалось, чтобы запустить приложение?
2. Как бы вы развернули это приложение на production-сервере?
3. Что произойдёт при перезапуске сервера? Потеряются ли данные?
4. Как вы узнаете, что приложение упало?

### Задание 1.2. Анализ по принципам DevOps (заполните таблицу)

| Принцип DevOps | Соблюдается? (Да/Нет/Частично) | Комментарий (проблема) |
|----------------|-------------------------------|------------------------|
| Инфраструктура как код | Нет | Нет Terraform/Ansible/CloudFormation |
| Контейнеризация | Нет | Запуск напрямую на хосте |
| CI/CD | Нет | Нет пайплайна, тестов, автоматической сборки |
| Декларативное управление конфигурацией | Нет | Конфиг в коде (PORT), но окружение не описано |
| Мониторинг и алертинг | Нет | Нет метрик, логов, алертов |
| Централизованное логирование | Нет | Логи в консоль, нет агрегации |
| Управление секретами | Нет | Нет переменных окружения для секретов |
| Автоматическое тестирование | Нет | Нет unit/e2e тестов |
| Blue-Green / Canary deployments | Нет | Простой запуск |
| Self-healing (восстановление) | Нет | При падении не перезапустится |

---

## Часть 2. Автоматизация запуска (система инициализации)

### Задание 2.1. Создайте systemd-сервис для приложения

Создайте файл `/etc/systemd/system/todoapp.service` (через sudo):

```bash
sudo tee /etc/systemd/system/todoapp.service << EOF
[Unit]
Description=Todo App Node.js
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/home/$USER/devops-lab/todo-app
ExecStart=/usr/bin/node app.js
Restart=on-failure
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable todoapp
sudo systemctl start todoapp
sudo systemctl status todoapp
```

**Анализ:** Какие проблемы DevOps это решило? (автозапуск, рестарт при падении, логи через journald)

### Задание 2.2. Настройка ротации и сбора логов

```bash
# Проверка логов
sudo journalctl -u todoapp -f --no-pager

# Проблема: нет структурированных логов (JSON)
```

**Улучшение:** Добавьте в `app.js` логирование в JSON (можно позже, как задание со звёздочкой).

---

## Часть 3. Контейнеризация (Docker)

### Задание 3.1. Установите Docker и напишите Dockerfile

```bash
# Установка Docker
sudo apt install -y docker.io
sudo systemctl enable docker --now
sudo usermod -aG docker $USER
# Выйдите и зайдите заново или выполните newgrp docker
```

Создайте `Dockerfile`:

```bash
cd ~/devops-lab/todo-app
cat > Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
# Проблема 4: База данных SQLite будет внутри контейнера — при пересоздании пропадёт
EXPOSE 3000
CMD ["node", "app.js"]
EOF
```

Создайте `.dockerignore`:

```bash
echo -e "node_modules\n.git\n*.log\ntodo.db" > .dockerignore
```

**Постройте и запустите:**

```bash
docker build -t todo-app:latest .
docker run -d -p 3000:3000 --name todo-app todo-app:latest
```

**Проблема:** При удалении контейнера теряются данные (SQLite внутри).

**Решение:** Добавить volume:

```bash
docker run -d -p 3000:3000 -v todo-data:/app --name todo-app todo-app:latest
```

**Вопрос:** Что теперь стало с портируемостью?

---

## Часть 4. CI/CD (GitLab CI / GitHub Actions)

### Задание 4.1. Настройка GitHub Actions (без реального репозитория — только конфиг)

Создайте каталог `.github/workflows` и файл `ci.yml`:

```bash
mkdir -p .github/workflows
cat > .github/workflows/ci.yml << 'EOF'
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test   # Тестов пока нет — это проблема
      - name: Build Docker image
        run: docker build -t todo-app:${{ github.sha }} .
      - name: Scan for vulnerabilities
        run: |
          docker scout quickview todo-app:${{ github.sha }} || true
  # Деплой (пример для VPS через SSH)
  deploy:
    needs: build-and-test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to server
        uses: appleboy/ssh-action@v0.1.5
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd ~/todo-app
            docker pull your-registry/todo-app:latest
            docker-compose up -d --force-recreate
EOF
```

**Анализ:** Какие недостатки выявлены в текущем приложении для CI/CD?
- Нет тестов (команда `npm test` упадёт)
- Нет реестра образов (Docker Hub / GHCR)
- Нет `docker-compose` для production

---

## Часть 5. Мониторинг и observability

### Задание 5.1. Добавление метрик (Prometheus)

Установите библиотеку:

```bash
npm install prom-client
```

Добавьте в `app.js` перед `app.listen`:

```javascript
const client = require('prom-client');
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
```

**Перезапустите и проверьте:** `curl http://localhost:3000/metrics`

### Задание 5.2. Установка Prometheus и Grafana (кратко)

```bash
# Docker Compose для мониторинга
cat > docker-compose.monitoring.yml << 'EOF'
version: '3'
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
EOF
```

Создайте `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'todo-app'
    static_configs:
      - targets: ['host.docker.internal:3000']
```

**Вопрос:** Почему без контейнеризации приложения мониторинг сложнее?

---

## Часть 6. Оценка зрелости по модели CALMS

Заполните таблицу для **текущего** приложения и **предлагаемого** после улучшений.

| Компонент CALMS | Текущее состояние | Целевое состояние (предложите) |
|----------------|-------------------|-------------------------------|
| **C**ulture | Разработка без Ops | Общая ответственность за продакшен |
| **A**utomation | Ручной запуск | CI/CD, Docker, systemd |
| **L**ean | Нет анализа потерь | Устранение ручных переходов |
| **M**easurement | Нет метрик | Prometheus + Grafana + логи |
| **S**haring | Нет общих практик | Документация как код, runbooks |

---

## Часть 7. Итоговый отчёт (оформление)

Создайте файл `DEVOPS_AUDIT_REPORT.md` со следующей структурой:

```markdown
# Отчёт по анализу приложения на соответствие DevOps

## 1. Резюме
Краткое описание приложения и основных проблем.

## 2. Результаты аудита (таблица из ч.1.2)

## 3. Выявленные антипаттерны
- Отсутствие тестов
- Состояние на хосте (база данных)
- Нет версионирования окружения
- ...

## 4. Предлагаемые улучшения (с приоритетами)
### Критичные (безопасность, отказоустойчивость)
### Важные (автоматизация)
### Желательные (мониторинг, метрики)

## 5. Оценка DORA метрик (текущая vs целевая)
- Deployment frequency: 1 раз в месяц → несколько раз в день
- Lead time for changes: дни → часы
- MTTR: часы → минуты
- Change failure rate: 30% → <5%

## 6. План внедрения (сроки, шаги)
1. Неделя 1: Docker + systemd
2. Неделя 2: CI/CD + тесты
3. Неделя 3: Мониторинг + алерты
```

---

## Контрольные вопросы (для защиты работы)

1. Почему приложение, которое работает на ноутбуке, может плохо работать в production с точки зрения DevOps?
2. Что даёт контейнеризация для повторяемости окружения?
3. Как CI/CD решает проблему "у меня работает, а на сервере нет"?
4. Назовите три метрики, которые нужно измерять в production, и объясните, почему без них DevOps невозможен.
5. Что такое "инфраструктура как код" и как её применить к данному приложению?

---

## Дополнительные задания (для углублённой работы)

### Задание со звёздочкой 1. Перепишите запуск на docker-compose с volume и healthcheck

```yaml
version: '3'
services:
  todo:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - todo-data:/app
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/todos"]
      interval: 30s
      retries: 3
volumes:
  todo-data:
```

### Задание со звёздочкой 2. Добавьте тесты (Jest) и включите в CI

```bash
npm install --save-dev jest supertest
# Создайте тест, проверяющий API
```

### Задание со звёздочкой 3. Настройте централизованное логирование (Loki + Promtail)

---

## Критерии оценки (максимум 100 баллов)

| Часть | Действие | Баллы |
|-------|----------|-------|
| 1 | Заполненная таблица аудита | 20 |
| 2 | Настроен systemd-сервис | 10 |
| 3 | Написан Dockerfile и запущен контейнер | 15 |
| 4 | Создан CI/CD конфиг (даже без выполнения) | 15 |
| 5 | Добавлены метрики Prometheus | 10 |
| 6 | Заполнен CALMS и отчёт | 20 |
| Контрольные | Ответы на вопросы (устно) | 10 |

---

## Завершение работы

```bash
# Остановка сервисов
sudo systemctl stop todoapp
docker stop todo-app
docker rm todo-app
```
