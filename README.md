# 🚀 Matrix Synapse Auto Installer v4.0

Автоматизований інсталятор Matrix Synapse з підтримкою мостів, моніторингу, резервного копіювання та веб інтерфейсу управління.

## ✨ Основні функції v4.0

### 🌐 Веб інтерфейс управління
- Сучасний Dashboard з інтуїтивним інтерфейсом
- Управління сервісами через браузер
- Моніторинг в реальному часі з графіками
- Система оновлень через веб інтерфейс
- Управління користувачами та резервним копіюванням

### ⚙️ Конфігурація через змінні середовища
- Повна автоматизація для Docker
- Гнучкість налаштування без інтерактивних запитів
- Безпечні паролі за замовчуванням

## 🚀 Швидкий старт

### 📦 Інтерактивне встановлення
```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/matrix-synapse-installer/main/install.sh | sudo bash
```

### ⚙️ Встановлення з змінними середовища
```bash
export MATRIX_DOMAIN=matrix.example.com
export MATRIX_INSTALL_ELEMENT=true
export MATRIX_SETUP_MONITORING=true
export MATRIX_WEB_DASHBOARD_ENABLED=true
curl -fsSL https://raw.githubusercontent.com/your-repo/matrix-synapse-installer/main/install.sh | sudo bash
```

### 🐳 Docker встановлення
```bash
docker run -d \
  -p 8080:80 \
  -p 8081:8081 \
  -e MATRIX_DOMAIN=matrix.example.com \
  -e MATRIX_WEB_DASHBOARD_ENABLED=true \
  -v /DATA/matrix:/DATA/matrix \
  ghcr.io/your-repo/matrix-synapse-installer:latest
```

## 🌐 Веб інтерфейс

### 📊 Доступ до сервісів
- Dashboard: http://your-domain:8081
- API: http://your-domain:8081/api
- Element Web: http://your-domain:80
- Grafana: http://your-domain:3000
- Prometheus: http://your-domain:9090

### 🛠️ Функції веб інтерфейсу
- Огляд системи — статус, статистика, ресурси
- Управління сервісами — запуск, зупинка, перезапуск
- Управління користувачами — створення, видалення
- Система оновлень — перевірка та встановлення
- Резервне копіювання — створення та відновлення
- Моніторинг — графіки та алерти

## ⚙️ Конфігурація

### 🔧 Основні змінні середовища
```bash
MATRIX_DOMAIN=matrix.example.com
MATRIX_BASE_DIR=/DATA/matrix
MATRIX_INSTALL_ELEMENT=true
MATRIX_INSTALL_BRIDGES=false
MATRIX_SETUP_MONITORING=true
MATRIX_SETUP_BACKUP=true
MATRIX_WEB_DASHBOARD_ENABLED=true
MATRIX_INSTALL_SIGNAL_BRIDGE=false
MATRIX_INSTALL_WHATSAPP_BRIDGE=false
MATRIX_INSTALL_DISCORD_BRIDGE=false
MATRIX_SSL_ENABLED=true
MATRIX_FIREWALL_ENABLED=true
MATRIX_RATE_LIMITING=true
```

### 📝 Приклади конфігурації

#### Docker Compose
```yaml
version: '3.8'
services:
  matrix-installer:
    image: ghcr.io/your-repo/matrix-synapse-installer:latest
    environment:
      - MATRIX_DOMAIN=matrix.example.com
      - MATRIX_INSTALL_ELEMENT=true
      - MATRIX_SETUP_MONITORING=true
      - MATRIX_WEB_DASHBOARD_ENABLED=true
    ports:
      - "8080:80"
      - "8081:8081"
    volumes:
      - matrix-data:/DATA/matrix
```

## 🛠️ Управління

### 🖥️ CLI команди
```bash
./bin/matrix-control.sh status
./bin/matrix-control.sh logs
./bin/matrix-control.sh backup create
./bin/matrix-control.sh backup list
./bin/matrix-control.sh update check
./bin/matrix-control.sh update perform
./bin/matrix-control.sh user create admin
./bin/matrix-control.sh user list
```

### 🌐 Веб API
```bash
curl http://localhost:8081/api/status
curl http://localhost:8081/api/overview
curl -X POST http://localhost:8081/api/services/synapse/restart
curl -X POST http://localhost:8081/api/users -H "Content-Type: application/json" -d '{"username":"testuser","password":"testpass"}'
```

## 🔧 Розробка

### 🐳 Локальна розробка
```bash
git clone https://github.com/your-repo/matrix-synapse-installer.git
cd matrix-synapse-installer
docker-compose -f docker-compose.dev.yml --profile dev up -d
```

## 📊 Моніторинг

- Використання ресурсів (CPU, RAM, Disk)
- Мережевий трафік в реальному часі
- Статус сервісів автоматичне відстеження
- Помилки та логи централізоване зборування
- Grafana алерти налаштування

## 🛡️ Безпека

- HTTPS обов'язковий для production
- Файрвол автоматичне налаштування
- Rate limiting захист від атак
- Валідація вхідних даних
- Безпечні паролі автоматична генерація

## 📚 Документація

- [📋 Інсталяція](docs/INSTALLATION.md)
- [🌐 Веб інтерфейс](docs/WEB_DASHBOARD.md)
- [🔧 Налаштування](docs/CONFIGURATION.md)
- [🛠️ Troubleshooting](docs/TROUBLESHOOTING.md)
- [🌉 Мости](docs/BRIDGES_SETUP.md)
- [☁️ Cloudflare Tunnel](docs/CLOUDFLARE_TUNNEL.md)
- [📊 Моніторинг](docs/MONITORING.md)
- [💾 Резервне копіювання](docs/BACKUP.md)

## 🤝 Внесок

1. Перевірте існуючі issues
2. Створіть нове issue з описом проблеми
3. Додайте логи та конфігурацію

## 📄 Ліцензія

Цей проект ліцензовано під MIT License.

## 🙏 Подяки

- Matrix.org — За чудовий протокол
- Synapse — За реалізацію сервера
- Element — За веб клієнт
- Docker — За контейнеризацію

**⭐ Якщо проект вам сподобався, поставте зірку на GitHub!**

## 📋 Передумови

### Системні вимоги
- **ОС:** Ubuntu 20.04+ або Debian 11+
- **RAM:** 2 GB (мінімум), 4 GB (рекомендовано)
- **Диск:** 10 GB вільного місця
- **Домен:** з правильно налаштованим DNS

### Залежності
Всі залежності встановлюються автоматично під час інсталяції:

- **Docker 20.10+** - контейнеризація
- **Python 3.8+** - веб API та скрипти
- **Nginx** - веб сервер та reverse proxy
- **PostgreSQL** - база даних
- **UFW** - файрвол
- **Fail2ban** - захист від атак
- **Certbot** - SSL сертифікати

📖 [Повний список залежностей](docs/DEPENDENCIES.md)


