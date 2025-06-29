# 🚀 Matrix Synapse Auto Installer v4.0

Автоматизований інсталятор Matrix Synapse з підтримкою Docker Compose, мостів, моніторингу та веб-інтерфейсу управління.

## ✨ Особливості

- 🐳 **Docker Compose архітектура** - Використання офіційних образів контейнерів
- 🌐 **Веб-інтерфейс управління** - Зручне управління через браузер
- 🌉 **Підтримка мостів** - Signal, WhatsApp, Discord інтеграція
- 📊 **Система моніторингу** - Prometheus, Grafana, Loki, Node Exporter
- ☁️ **Cloudflare Tunnel** - Безпечний доступ без публічного IP
- 🔒 **Розширена безпека** - SSL, файрвол, fail2ban, валідація
- 💾 **Автоматичне резервне копіювання** - Cron-based резервні копії
- 🧪 **Тестування** - Автоматична перевірка залежностей
- 📱 **Element Web** - Офіційний Matrix клієнт
- 🐳 **Portainer** - Візуальне управління контейнерами

## 🏗️ Архітектура

```
matrix-synapse-installer/
├── docker-compose.yml          # Основна конфігурація Docker Compose
├── install.sh                  # Головний інсталятор
├── bin/
│   └── matrix-control.sh       # Скрипт управління сервісами
├── lib/                        # Модулі інсталятора
├── web/                        # Веб-інтерфейс управління
├── docs/                       # Документація
└── tests/                      # Тести
```

## 🐳 Офіційні образи контейнерів

- **matrixdotorg/synapse** - Matrix Synapse сервер
- **postgres:15-alpine** - PostgreSQL база даних
- **redis:7-alpine** - Redis кеш
- **nginx:alpine** - Nginx веб-сервер
- **grafana/grafana** - Grafana дашборди
- **prom/prometheus** - Prometheus метрики
- **prom/node-exporter** - Node Exporter
- **grafana/loki** - Loki логи
- **grafana/promtail** - Promtail збір логів
- **cloudflare/cloudflared** - Cloudflare Tunnel
- **portainer/portainer-ce** - Portainer управління
- **dock.mau.dev/mautrix/signal** - Signal Bridge
- **dock.mau.dev/mautrix/whatsapp** - WhatsApp Bridge
- **dock.mau.dev/mautrix/discord** - Discord Bridge

## 🚀 Швидкий старт

### 1. Клонування репозиторію
```bash
git clone https://github.com/Karnemorkon/matrix-synapse-installer.git
cd matrix-synapse-installer
```

### 2. Запуск інсталятора
```bash
# Інтерактивне встановлення
./install.sh

# Або з змінними середовища
MATRIX_DOMAIN=matrix.example.com ./install.sh
```

### 3. Управління сервісами
```bash
# Запуск всіх сервісів
./bin/matrix-control.sh start

# Статус сервісів
./bin/matrix-control.sh status

# Логи конкретного сервісу
./bin/matrix-control.sh logs synapse

# Оновлення образів
./bin/matrix-control.sh update
```

## ⚙️ Конфігурація

### Змінні середовища

| Змінна | Опис | За замовчуванням |
|--------|------|------------------|
| `MATRIX_DOMAIN` | Домен для Matrix сервера | `matrix.localhost` |
| `MATRIX_BASE_DIR` | Базова директорія | `/opt/matrix` |
| `MATRIX_POSTGRES_PASSWORD` | Пароль PostgreSQL | Генерується |
| `MATRIX_ALLOW_PUBLIC_REGISTRATION` | Публічна реєстрація | `false` |
| `MATRIX_ENABLE_FEDERATION` | Федерація | `false` |
| `MATRIX_INSTALL_ELEMENT` | Element Web | `true` |
| `MATRIX_INSTALL_BRIDGES` | Мости | `false` |
| `MATRIX_SETUP_MONITORING` | Моніторинг | `true` |
| `MATRIX_SETUP_BACKUP` | Резервне копіювання | `true` |
| `MATRIX_USE_CLOUDFLARE_TUNNEL` | Cloudflare Tunnel | `false` |
| `MATRIX_CLOUDFLARE_TUNNEL_TOKEN` | Токен Cloudflare | - |
| `MATRIX_WEB_DASHBOARD_ENABLED` | Веб-інтерфейс | `true` |
| `MATRIX_WEB_DASHBOARD_PORT` | Порт веб-інтерфейсу | `8081` |

### Профілі Docker Compose

- **Основні сервіси**: `postgres`, `redis`, `synapse`, `nginx`
- **Моніторинг**: `--profile monitoring`
- **Мости**: `--profile bridges`
- **Element Web**: `--profile element`
- **Cloudflare Tunnel**: `--profile cloudflare`
- **Portainer**: `--profile portainer`

## 🌐 Доступні сервіси

Після встановлення будуть доступні:

- **Matrix Synapse**: `http://your-domain:8008`
- **Element Web**: `https://your-domain`
- **Веб-інтерфейс**: `http://localhost:8081`
- **Grafana**: `http://localhost:3000`
- **Prometheus**: `http://localhost:9090`
- **Portainer**: `http://localhost:9000`
- **Loki**: `http://localhost:3100`

## 🔧 Управління

### Основні команди
```bash
# Запуск/зупинка
./bin/matrix-control.sh start
./bin/matrix-control.sh stop
./bin/matrix-control.sh restart

# Моніторинг
./bin/matrix-control.sh status
./bin/matrix-control.sh logs [сервіс]

# Резервне копіювання
./bin/matrix-control.sh backup
./bin/matrix-control.sh restore <файл>

# Оновлення
./bin/matrix-control.sh update

# Додаткові сервіси
./bin/matrix-control.sh monitoring
./bin/matrix-control.sh bridges
./bin/matrix-control.sh portainer
./bin/matrix-control.sh cloudflare
```

### Docker Compose команди
```bash
# Запуск з профілями
docker compose --profile monitoring up -d
docker compose --profile bridges up -d
docker compose --profile portainer up -d

# Перегляд логів
docker compose logs -f synapse
docker compose logs -f nginx

# Оновлення образів
docker compose pull
docker compose up -d
```

## 📚 Документація

- [📖 Детальний гід встановлення](docs/INSTALLATION.md)
- [🌉 Налаштування мостів](docs/BRIDGES_SETUP.md)
- [☁️ Cloudflare Tunnel](docs/CLOUDFLARE_TUNNEL.md)
- [📊 Моніторинг](docs/MONITORING.md)
- [🔒 Безпека](docs/SECURITY.md)
- [💾 Резервне копіювання](docs/BACKUP.md)
- [🌐 Веб-інтерфейс](docs/WEB_DASHBOARD.md)
- [🧪 Тестування](docs/TESTING.md)
- [📋 Залежності](docs/DEPENDENCIES.md)
- [🔧 Виправлення проблем](docs/TROUBLESHOOTING.md)
- [📈 Покращення](docs/IMPROVEMENTS.md)
- [📝 Історія змін](docs/CHANGELOG.md)

## 🧪 Тестування

```bash
# Перевірка залежностей
./tests/test-dependencies.sh

# Тест встановлення
./tests/test-installation.sh

# Перевірка конфігурації
./tests/test-config.sh
```

## 🔒 Безпека

- ✅ SSL/TLS сертифікати (Let's Encrypt)
- ✅ Файрвол (UFW)
- ✅ Захист від атак (fail2ban)
- ✅ Валідація вхідних даних
- ✅ Безпечні заголовки HTTP
- ✅ Обмеження швидкості запитів
- ✅ Cloudflare Tunnel підтримка

## 🌉 Підтримувані мости

- 📱 **Signal Bridge** - Інтеграція з Signal
- 💬 **WhatsApp Bridge** - Інтеграція з WhatsApp
- 🎮 **Discord Bridge** - Інтеграція з Discord

## 📊 Моніторинг

- **Prometheus** - Збір метрик
- **Grafana** - Візуалізація даних
- **Node Exporter** - Системні метрики
- **Loki** - Збір логів
- **Promtail** - Агент збору логів

## 🤝 Внесок

1. Форкніть репозиторій
2. Створіть гілку для нової функції (`git checkout -b feature/amazing-feature`)
3. Зробіть коміт змін (`git commit -m 'Add amazing feature'`)
4. Запушіть в гілку (`git push origin feature/amazing-feature`)
5. Відкрийте Pull Request

## 📄 Ліцензія

Цей проект ліцензовано під MIT License - дивіться файл [LICENSE](LICENSE) для деталей.

## 🙏 Подяки

- [Matrix.org](https://matrix.org/) - За Matrix протокол
- [Element](https://element.io/) - За Element Web клієнт
- [Docker](https://docker.com/) - За контейнеризацію
- [Cloudflare](https://cloudflare.com/) - За Cloudflare Tunnel
- [Grafana](https://grafana.com/) - За моніторинг
- [Prometheus](https://prometheus.io/) - За метрики

## 📞 Підтримка

Якщо у вас виникли питання або проблеми:

1. Перевірте [документацію](docs/)
2. Подивіться [виправлення проблем](docs/TROUBLESHOOTING.md)
3. Відкрийте [Issue](https://github.com/Karnemorkon/matrix-synapse-installer/issues)

---

**Matrix Synapse Auto Installer v4.0** - Зроблено з ❤️ для спільноти Matrix


