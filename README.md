# 🏠 Matrix Synapse Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04+-orange.svg)](https://ubuntu.com/)
[![Matrix](https://img.shields.io/badge/Matrix-Synapse-green.svg)](https://matrix.org/)

Автоматизований інсталятор для Matrix Synapse сервера з підтримкою мостів, моніторингу та резервного копіювання.

## 🌟 Особливості

- 🚀 **Швидке встановлення** - повна автоматизація процесу
- 🏗️ **Docker-based** - ізольоване середовище
- 🌉 **Підтримка мостів** - Signal, WhatsApp, Discord
- 📊 **Моніторинг** - Prometheus + Grafana
- 💾 **Резервне копіювання** - автоматичне створення бекапів
- 🔒 **Безпека** - SSL сертифікати, файрвол, валідація
- 🌐 **Cloudflare Tunnel** - безпечний доступ без публічного IP
- 🎛️ **Управління** - зручний скрипт контролю
- 🔧 **Модульна архітектура** - легке розширення функціональності

## 📋 Системні вимоги

- **ОС:** Ubuntu 20.04+ або Debian 11+
- **RAM:** 2 GB (мінімум), 4 GB (рекомендовано)
- **Диск:** 10 GB вільного місця
- **Docker:** версія 20.10+
- **Docker Compose:** версія 2.0+
- **Домен:** з правильно налаштованим DNS

## 🚀 Швидкий старт

```bash
sudo apt update -y && sudo apt upgrade -y && sudo apt install git -y
# Завантажити інсталятор
git clone https://github.com/Karnemorkon/matrix-synapse-installer.git
cd matrix-synapse-installer

# Надати права на виконання
chmod +x install.sh
chmod +x bin/matrix-control.sh

# Запустити встановлення
sudo ./install.sh
```

## 🌉 Підтримувані мости

### 📱 Signal Bridge
- ✅ Інтеграція з Signal месенджером
- ✅ Підтримка груп та приватних повідомлень
- ✅ Автоматична синхронізація контактів
- ✅ Безпечна автентифікація

### 💬 WhatsApp Bridge
- ✅ Інтеграція з WhatsApp
- ✅ QR-код автентифікація
- ✅ Підтримка медіа файлів
- ✅ Групові чати

### 🎮 Discord Bridge
- ✅ Інтеграція з Discord серверами
- ✅ Підтримка каналів та ролей
- ✅ Webhook інтеграція
- ✅ Синхронізація повідомлень

## 🎛️ Управління

### Основні команди

```bash
# Запуск/зупинка сервісів
./bin/matrix-control.sh start
./bin/matrix-control.sh stop
./bin/matrix-control.sh restart

# Перегляд статусу та логів
./bin/matrix-control.sh status
./bin/matrix-control.sh logs

# Управління користувачами
./bin/matrix-control.sh user create admin
./bin/matrix-control.sh user list
./bin/matrix-control.sh user delete username

# Управління мостами
./bin/matrix-control.sh bridge list
./bin/matrix-control.sh bridge status signal
./bin/matrix-control.sh bridge setup whatsapp
./bin/matrix-control.sh bridge restart discord

# Резервне копіювання
./bin/matrix-control.sh backup
./bin/matrix-control.sh restore backup-file.tar.gz

# SSL сертифікати
./bin/matrix-control.sh ssl check
./bin/matrix-control.sh ssl renew

# Очищення та обслуговування
./bin/matrix-control.sh cleanup
```

## 🏗️ Архітектура

```
matrix-synapse-installer/
├── 📁 bin/                    # Виконувані скрипти
│   └── matrix-control.sh     # Скрипт управління
├── 📁 lib/                    # Модулі функціональності
│   ├── config.sh             # Конфігурація
│   ├── docker.sh             # Docker управління
│   ├── matrix.sh             # Matrix Synapse
│   ├── bridges.sh            # Мости
│   ├── monitoring.sh         # Моніторинг
│   ├── backup.sh             # Резервне копіювання
│   ├── security.sh           # Безпека
│   ├── validator.sh          # Валідація
│   └── logger.sh             # Логування
├── 📁 docs/                   # Документація
├── 📁 examples/               # Приклади конфігурацій
├── 📁 tests/                  # Тести
└── install.sh                # Головний інсталятор

🌐 ДОСТУП ДО СЕРВІСІВ:
├── Element Web: https://yourdomain.com (публічний)
├── Matrix API: https://yourdomain.com/_matrix (публічний)
├── Synapse Admin: http://localhost:8080 (локальний)
├── Grafana: http://localhost:3000 (локальний)
└── Prometheus: http://localhost:9090 (локальний)
```

## 🔧 Налаштування

### Конфігурація під час встановлення
- 🌐 Домен для Matrix сервера
- 📁 Базова директорія встановлення
- 🔐 Пароль для PostgreSQL
- 🌉 Вибір мостів (Signal, WhatsApp, Discord)
- 📊 Налаштування моніторингу
- 💾 Конфігурація резервного копіювання

### Після встановлення
- 🔒 Налаштування SSL сертифікатів
- 🌉 Конфігурація мостів
- 🛡️ Налаштування файрволу
- 👥 Створення користувачів

## 🛡️ Безпека

- 🔐 **SSL/TLS шифрування** - захист трафіку
- 🛡️ **Файрвол** - з rate limiting
- 🔑 **Безпечні паролі** - автоматична генерація
- 📊 **Моніторинг безпеки** - відстеження загроз
- 🔄 **Регулярні оновлення** - актуальність системи

## 📚 Документація

### 📖 Основна документація
- [📋 Гід встановлення](docs/INSTALLATION.md) - детальні інструкції
- [🌉 Налаштування мостів](docs/BRIDGES_SETUP.md) - конфігурація мостів
- [🔧 Усунення проблем](docs/TROUBLESHOOTING.md) - рішення проблем
- [🌐 Cloudflare Tunnel](docs/CLOUDFLARE_TUNNEL.md) - налаштування безпечного доступу

### 🧪 Тестування
- [🧪 Тести](tests/README.md) - автоматизовані тести
- [📊 Тестова конфігурація](tests/test-installation.sh) - скрипт тестування

### ⚙️ Приклади конфігурацій
- [🐳 Docker Compose](examples/docker-compose.advanced.yml) - розширена конфігурація
- [🌉 Конфігурація мостів](examples/bridge-config-example.yaml) - приклад налаштування мостів

## 🤝 Внесок

Ми вітаємо внески! Будь ласка, дотримуйтесь цих кроків:

1. 🍴 Форк репозиторію
2. 🌿 Створіть гілку для нової функції (`git checkout -b feature/amazing-feature`)
3. 💾 Зробіть коміт змін (`git commit -m 'Add amazing feature'`)
4. 📤 Відправте в гілку (`git push origin feature/amazing-feature`)
5. 🔄 Створіть Pull Request

### Вимоги до коду
- ✅ Дотримуйтесь стилю коду
- ✅ Додайте тести для нової функціональності
- ✅ Оновіть документацію
- ✅ Перевірте, що всі тести проходять

## 🐛 Повідомлення про помилки

Якщо ви знайшли помилку, будь ласка:

1. Перевірте [документацію](docs/TROUBLESHOOTING.md)
2. Пошукайте в [існуючих issues](https://github.com/Karnemorkon/matrix-synapse-installer/issues)
3. Створіть нове issue з детальним описом проблеми

## 📄 Ліцензія

Цей проект розповсюджується під ліцензією MIT. Дивіться файл [LICENSE](LICENSE) для деталей.

## 🆘 Підтримка

- 📖 [Документація](docs/)
- 🐛 [Issues](https://github.com/Karnemorkon/matrix-synapse-installer/issues)
- 💬 [Discussions](https://github.com/Karnemorkon/matrix-synapse-installer/discussions)
- 📧 Email: karnemorkon@gmail.com

## 🙏 Подяки

- [Matrix.org](https://matrix.org/) - за Matrix протокол
- [Mautrix](https://github.com/mautrix) - за мости
- [Element](https://element.io/) - за клієнт
- [Docker](https://docker.com/) - за контейнеризацію
- [Prometheus](https://prometheus.io/) - за моніторинг
- [Grafana](https://grafana.com/) - за візуалізацію

## 📊 Статистика

![GitHub stars](https://img.shields.io/github/stars/Karnemorkon/matrix-synapse-installer)
![GitHub forks](https://img.shields.io/github/forks/Karnemorkon/matrix-synapse-installer)
![GitHub issues](https://img.shields.io/github/issues/Karnemorkon/matrix-synapse-installer)
![GitHub pull requests](https://img.shields.io/github/issues-pr/Karnemorkon/matrix-synapse-installer)


