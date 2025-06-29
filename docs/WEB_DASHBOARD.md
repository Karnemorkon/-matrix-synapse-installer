# 🌐 Веб інтерфейс управління Matrix Synapse

## 📋 Огляд

Веб інтерфейс управління Matrix Synapse надає зручний спосіб керування сервером через браузер. Інтерфейс включає всі основні функції управління та моніторингу.

## 🚀 Функції

### 📊 Огляд системи
- **Статус сервісів** в реальному часі
- **Статистика користувачів** та кімнат
- **Використання ресурсів** (CPU, RAM, Disk)
- **Мережевий трафік** та активність

### 🛠️ Управління сервісами
- **Запуск/зупинка** сервісів
- **Перезапуск** окремих компонентів
- **Перегляд логів** в реальному часі
- **Моніторинг статусу** всіх сервісів

### 👥 Управління користувачами
- **Створення** нових користувачів
- **Видалення** користувачів
- **Перегляд** списку користувачів
- **Управління правами** доступу

### 🔄 Система оновлень
- **Перевірка** доступних оновлень
- **Автоматичне оновлення** системи
- **Моніторинг прогресу** оновлення
- **Історія оновлень**

### 💾 Резервне копіювання
- **Створення** резервних копій
- **Перегляд** списку резервних копій
- **Відновлення** з резервної копії
- **Налаштування** розкладу

### ⚙️ Налаштування
- **Конфігурація** домену
- **Налаштування** безпеки
- **Управління** мостами
- **Моніторинг** параметри

## 🏗️ Архітектура

### 📁 Структура файлів
```
web/
├── dashboard/
│   ├── index.html      # Головна сторінка
│   ├── styles.css      # Стилі інтерфейсу
│   └── script.js       # JavaScript логіка
├── api-server.py       # Python API сервер
└── requirements.txt    # Python залежності
```

### 🔌 API Endpoints

#### Статус системи
```http
GET /api/status
```
**Відповідь:**
```json
{
  "status": "online|offline",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

#### Огляд системи
```http
GET /api/overview
```
**Відповідь:**
```json
{
  "activeUsers": 150,
  "totalRooms": 45,
  "runningServices": 8,
  "diskUsage": "75%",
  "cpuUsage": "25%",
  "memoryUsage": "60%"
}
```

#### Управління сервісами
```http
GET /api/services
POST /api/services/{name}/start
POST /api/services/{name}/stop
POST /api/services/{name}/restart
```

#### Управління користувачами
```http
GET /api/users
POST /api/users
DELETE /api/users/{username}
```

#### Система оновлень
```http
GET /api/updates
POST /api/updates/check
POST /api/updates/perform
GET /api/updates/progress
```

#### Резервне копіювання
```http
POST /api/backup
GET /api/backup
```

## 🛠️ Встановлення та налаштування

### 🔧 Автоматичне встановлення
Веб інтерфейс встановлюється автоматично при використанні основного інсталятора:

```bash
# Встановлення з увімкненим веб інтерфейсом
MATRIX_WEB_DASHBOARD_ENABLED=true ./install.sh
```

### ⚙️ Ручне встановлення
```bash
# Копіювання файлів
cp -r web/ /DATA/matrix/

# Встановлення Python залежностей
pip3 install flask flask-cors pyyaml requests psutil docker

# Запуск API сервера
python3 /DATA/matrix/web/api-server.py
```

### 🔧 Налаштування nginx
```nginx
server {
    listen 80;
    server_name matrix.example.com;
    
    location / {
        root /DATA/matrix/web/dashboard;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 🔐 Безпека

### 🛡️ Заходи безпеки
- **HTTPS** обов'язковий для production
- **Аутентифікація** користувачів
- **Валідація** вхідних даних
- **Rate limiting** для API
- **CORS** налаштування
- **Заголовки безпеки**

### 🔑 Аутентифікація
```python
# Приклад middleware для аутентифікації
@app.before_request
def require_auth():
    if request.endpoint.startswith('api.'):
        token = request.headers.get('Authorization')
        if not validate_token(token):
            return jsonify({'error': 'Unauthorized'}), 401
```

## 📊 Моніторинг

### 📈 Метрики
- **Response time** API запитів
- **Error rate** помилок
- **Active users** активних користувачів
- **System resources** використання ресурсів

### 🔍 Логування
```python
import logging

# Налаштування логування
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/matrix/web-api.log'),
        logging.StreamHandler()
    ]
)
```

## 🚀 Розробка

### 🔧 Локальна розробка
```bash
# Клонування репозиторію
git clone https://github.com/your-repo/matrix-synapse-installer.git
cd matrix-synapse-installer

# Запуск в режимі розробки
docker-compose -f docker-compose.dev.yml --profile dev up -d

# Доступ до сервісів
# Веб інтерфейс: http://localhost:8080
# API: http://localhost:8081/api
# Grafana: http://localhost:3000
# Prometheus: http://localhost:9090
```

### 🧪 Тестування
```bash
# Unit тести
cd web
python -m pytest tests/ -v

# Тестування API
curl -X GET http://localhost:8081/api/status

# Тестування веб інтерфейсу
npm test  # якщо використовується
```

### 📦 Збірка
```bash
# Збірка Docker образу
docker build -t matrix-synapse-installer:latest .

# Запуск контейнера
docker run -d \
  -p 8080:80 \
  -p 8081:8081 \
  -v /DATA/matrix:/DATA/matrix \
  matrix-synapse-installer:latest
```

## 🔧 Налаштування

### ⚙️ Конфігурація
```python
# config.py
class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key'
    API_HOST = os.environ.get('API_HOST') or '0.0.0.0'
    API_PORT = int(os.environ.get('API_PORT') or 8081)
    DEBUG = os.environ.get('FLASK_DEBUG') == '1'
```

### 🔧 Змінні середовища
```bash
# Основні налаштування
MATRIX_WEB_DASHBOARD_PORT=8081
MATRIX_WEB_DASHBOARD_ENABLED=true

# Безпека
SECRET_KEY=your-secret-key
API_HOST=0.0.0.0

# Розробка
FLASK_ENV=development
FLASK_DEBUG=1
```

## 🚨 Troubleshooting

### ❌ Часті проблеми

#### 1. API недоступний
```bash
# Перевірка статусу сервіса
systemctl status matrix-api

# Перевірка логів
tail -f /var/log/matrix/api.log

# Перевірка портів
netstat -tlnp | grep 8081
```

#### 2. Веб інтерфейс не завантажується
```bash
# Перевірка nginx
nginx -t
systemctl status nginx

# Перевірка файлів
ls -la /DATA/matrix/web/dashboard/
```

#### 3. Помилки CORS
```python
# Налаштування CORS
from flask_cors import CORS

app = Flask(__name__)
CORS(app, origins=['https://matrix.example.com'])
```

### 🔍 Діагностика
```bash
# Перевірка всіх сервісів
./bin/matrix-control.sh status

# Перевірка логів
./bin/matrix-control.sh logs

# Тестування API
curl -X GET http://localhost:8081/api/status
```

## 📚 API Документація

### 🔌 Повний список endpoints

#### Система
- `GET /api/status` - Статус системи
- `GET /api/overview` - Загальна статистика
- `GET /api/health` - Перевірка здоров'я

#### Сервіси
- `GET /api/services` - Список сервісів
- `POST /api/services/{name}/start` - Запуск сервісу
- `POST /api/services/{name}/stop` - Зупинка сервісу
- `POST /api/services/{name}/restart` - Перезапуск сервісу
- `GET /api/services/{name}/logs` - Логи сервісу

#### Користувачі
- `GET /api/users` - Список користувачів
- `POST /api/users` - Створення користувача
- `DELETE /api/users/{username}` - Видалення користувача
- `PUT /api/users/{username}` - Оновлення користувача

#### Оновлення
- `GET /api/updates` - Інформація про оновлення
- `POST /api/updates/check` - Перевірка оновлень
- `POST /api/updates/perform` - Виконання оновлення
- `GET /api/updates/progress` - Прогрес оновлення

#### Резервне копіювання
- `GET /api/backup` - Список резервних копій
- `POST /api/backup` - Створення резервної копії
- `POST /api/backup/{id}/restore` - Відновлення
- `DELETE /api/backup/{id}` - Видалення резервної копії

#### Моніторинг
- `GET /api/monitoring/metrics` - Метрики системи
- `GET /api/monitoring/alerts` - Активні алерти
- `GET /api/monitoring/logs` - Логи системи

### 📝 Приклади використання

#### JavaScript
```javascript
// Отримання статусу системи
fetch('/api/status')
  .then(response => response.json())
  .then(data => {
    console.log('Статус:', data.status);
  });

// Запуск сервісу
fetch('/api/services/synapse/start', {
  method: 'POST'
})
  .then(response => response.json())
  .then(data => {
    console.log('Результат:', data);
  });
```

#### Python
```python
import requests

# Отримання статистики
response = requests.get('http://localhost:8081/api/overview')
data = response.json()
print(f"Активних користувачів: {data['activeUsers']}")

# Створення користувача
user_data = {
    'username': 'newuser',
    'password': 'secure_password',
    'isAdmin': False
}
response = requests.post('http://localhost:8081/api/users', json=user_data)
```

#### cURL
```bash
# Перевірка статусу
curl -X GET http://localhost:8081/api/status

# Створення користувача
curl -X POST http://localhost:8081/api/users \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpass"}'

# Запуск сервісу
curl -X POST http://localhost:8081/api/services/synapse/start
```

## 🔮 Майбутні покращення

### 🎯 Планується:
- [ ] **Мобільний додаток** для управління
- [ ] **Push сповіщення** для алертів
- [ ] **Розширена аналітика** використання
- [ ] **Інтеграція з LDAP** для аутентифікації
- [ ] **Webhook підтримка** для інтеграцій
- [ ] **Темна тема** інтерфейсу
- [ ] **Мультимовність** підтримка
- [ ] **Розширені права** доступу

### 📊 Метрики розвитку:
- **Покриття тестами:** 90%+
- **Час відповіді API:** <100ms
- **Доступність:** 99.9%
- **Безпека:** OWASP Top 10 compliance

## 📞 Підтримка

### 🆘 Отримання допомоги:
- **GitHub Issues:** [Створити issue](https://github.com/your-repo/matrix-synapse-installer/issues)
- **Документація:** [Повна документація](https://github.com/your-repo/matrix-synapse-installer/docs)
- **Discord:** [Сервер спільноти](https://discord.gg/matrix-installer)

### 📚 Корисні посилання:
- [Flask Documentation](https://flask.palletsprojects.com/)
- [Matrix Synapse Documentation](https://matrix-org.github.io/synapse/)
- [Web Development Best Practices](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps) 