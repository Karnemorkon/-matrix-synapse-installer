# 🏠 Matrix Synapse Installer

Автоматизований інсталятор для Matrix Synapse сервера з підтримкою мостів, моніторингу та резервного копіювання.

## 🌟 Особливості

- 🚀 **Швидке встановлення** - повна автоматизація процесу
- 🏗️ **Docker-based** - ізольоване середовище
- 🌉 **Підтримка мостів** - Signal, WhatsApp, Discord
- 📊 **Моніторинг** - Prometheus + Grafana
- 💾 **Резервне копіювання** - автоматичне створення бекапів
- 🔒 **Безпека** - SSL сертифікати, файрвол, валідація
- 🎛️ **Управління** - зручний скрипт контролю

## 📋 Системні вимоги

- Ubuntu 20.04+ або Debian 11+
- 2 GB RAM (мінімум)
- 10 GB вільного місця
- Docker та Docker Compose
- Домен з правильно налаштованим DNS

## 🚀 Швидкий старт

```bash
# Завантажити інсталятор
git clone https://github.com/your-username/matrix-synapse-installer.git
cd matrix-synapse-installer

# Запустити встановлення
sudo ./install.sh
```

## 🌉 Підтримувані мости

### 📱 Signal Bridge
- Інтеграція з Signal месенджером
- Підтримка груп та приватних повідомлень
- Автоматична синхронізація контактів

### 💬 WhatsApp Bridge
- Інтеграція з WhatsApp
- QR-код автентифікація
- Підтримка медіа файлів

### 🎮 Discord Bridge
- Інтеграція з Discord серверами
- Підтримка каналів та ролей
- Webhook інтеграція

## 🎛️ Управління

### Основні команди
```bash
# Запуск/зупинка
./bin/matrix-control.sh start
./bin/matrix-control.sh stop
./bin/matrix-control.sh restart

# Статус та логи
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

# Очищення
./bin/matrix-control.sh cleanup
```

## 📚 Документація

### 📖 Основна документація
- [📋 Гід встановлення](docs/INSTALLATION.md) - детальні інструкції
- [🌉 Налаштування мостів](docs/BRIDGES_SETUP.md) - конфігурація мостів
- [🔧 Усунення проблем](docs/TROUBLESHOOTING.md) - рішення проблем
- [📈 Покращення](docs/IMPROVEMENTS.md) - рекомендації та плани

### 🧪 Тестування
- [🧪 Тести](tests/README.md) - автоматизовані тести
- [📊 Тестова конфігурація](tests/test-installation.sh) - скрипт тестування

### ⚙️ Приклади конфігурацій
- [🐳 Docker Compose](examples/docker-compose.advanced.yml) - розширена конфігурація
- [🌉 Конфігурація мостів](examples/bridge-config-example.yaml) - приклад налаштування мостів

### 📝 Інформаційні файли
- [🌉 Покращення мостів](BRIDGES_IMPROVEMENT.md) - опис системи мостів
- [📊 Аналіз проекту](docs/ANALYSIS.md) - технічний аналіз
- [🔒 Безпека](docs/SECURITY.md) - рекомендації з безпеки

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
│   └── validator.sh          # Валідація
├── 📁 docs/                   # Документація
├── 📁 examples/               # Приклади
├── 📁 tests/                  # Тести
└── install.sh                # Головний інсталятор
```

## 🔧 Налаштування

### Конфігурація під час встановлення
- Домен для Matrix сервера
- Базова директорія встановлення
- Пароль для PostgreSQL
- Вибір мостів (Signal, WhatsApp, Discord)
- Налаштування моніторингу
- Конфігурація резервного копіювання

### Після встановлення
- Налаштування SSL сертифікатів
- Конфігурація мостів
- Налаштування файрволу
- Створення користувачів

## 🛡️ Безпека

- 🔐 SSL/TLS шифрування
- 🛡️ Файрвол з rate limiting
- 🔑 Безпечні паролі
- 📊 Моніторинг безпеки
- 🔄 Регулярні оновлення

## 🤝 Внесок

1. Форк репозиторію
2. Створіть гілку для нової функції
3. Внесіть зміни
4. Додайте тести
5. Створіть Pull Request

## 📄 Ліцензія

Цей проект розповсюджується під ліцензією MIT. Дивіться файл [LICENSE](LICENSE) для деталей.

## 🆘 Підтримка

- 📖 [Документація](docs/)
- 🐛 [Issues](https://github.com/your-username/matrix-synapse-installer/issues)
- 💬 [Discussions](https://github.com/your-username/matrix-synapse-installer/discussions)

## 🙏 Подяки

- [Matrix.org](https://matrix.org/) - за Matrix протокол
- [Mautrix](https://github.com/mautrix) - за мости
- [Element](https://element.io/) - за клієнт
- [Docker](https://docker.com/) - за контейнеризацію

---

**Версія:** 3.1  
**Останнє оновлення:** $(date)  
**Автор:** AI Assistant
