# Matrix Synapse Auto Installer 3.0

🚀 **Повністю переписаний автоматизований інсталятор Matrix Synapse з модульною архітектурою**

[![Version](https://img.shields.io/badge/Version-3.0-blue.svg)](https://github.com/your-username/matrix-synapse-installer)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

## 📋 Зміст

- [Що нового в версії 3.0](#що-нового-в-версії-30)
- [Системні вимоги](#системні-вимоги)
- [Швидкий старт](#швидкий-старт)
- [Детальна інструкція](#детальна-інструкція)
- [Конфігурація](#конфігурація)
- [Управління системою](#управління-системою)
- [Резервне копіювання](#резервне-копіювання)
- [Моніторинг](#моніторинг)
- [Мости](#мости)
- [Усунення проблем](#усунення-проблем)
- [Підтримка](#підтримка)
- [Ліцензія](#ліцензія)
- [Подяки](#подяки)

## 🎯 Що нового в версії 3.0

### 🏗️ Модульна архітектура
- **Розділені модулі** для кожної функціональності
- **Централізоване логування** з різними рівнями
- **Конфігураційна система** з валідацією
- **Покращена обробка помилок**

### 🔧 Покращене управління
- **Інтерактивний скрипт управління** `matrix-control.sh`
- **Автоматична валідація** системних вимог
- **Розширена діагностика** здоров'я системи
- **Централізоване управління користувачами**

### 📊 Розширений моніторинг
- **Prometheus + Grafana** з готовими дашбордами
- **Alertmanager** для email сповіщень
- **Системні метрики** через Node Exporter
- **Метрики PostgreSQL** через спеціальний експортер

### 💾 Покращене резервне копіювання
- **Автоматичні бекапи** з ротацією
- **Скрипт відновлення** з валідацією
- **Консистентні бекапи** з зупинкою сервісів
- **Гнучкий розклад** (щодня/щотижня/вручну)

## 📥 Структура проекту

\`\`\`
matrix-synapse-installer/
├── install.sh                 # Головний скрипт встановлення
├── lib/                      # Модулі функціональності
│   ├── logger.sh            # Система логування
│   ├── config.sh            # Управління конфігурацією
│   ├── validator.sh         # Валідація системи та вводу
│   ├── docker.sh            # Docker функціональність
│   ├── matrix.sh            # Matrix Synapse специфіка
│   ├── bridges.sh           # Мости Mautrix
│   ├── monitoring.sh        # Prometheus/Grafana
│   ├── backup.sh            # Резервне копіювання
│   └── security.sh          # SSL та безпека
├── bin/                     # Виконувані скрипти
│   └── matrix-control.sh    # Головний скрипт управління
├── templates/               # Шаблони конфігурацій
├── docs/                    # Документація
└── README.md               # Цей файл
\`\`\`

## 🚀 Швидкий старт

### 1. Завантаження

\`\`\`bash
git clone https://github.com/your-username/matrix-synapse-installer.git
cd matrix-synapse-installer
chmod +x install.sh
\`\`\`

### 2. Запуск встановлення

\`\`\`bash
sudo ./install.sh
\`\`\`

### 3. Слідування майстру встановлення

Скрипт проведе вас через всі необхідні кроки:
- ✅ Перевірка системних вимог
- ⚙️ Інтерактивна конфігурація
- 🔐 Налаштування безпеки
- 🐳 Встановлення Docker сервісів
- 📊 Налаштування моніторингу
- 💾 Система резервного копіювання

## 📋 Системні вимоги

### Мінімальні вимоги
- **ОС**: Ubuntu 20.04+ / Debian 11+
- **RAM**: 2GB (рекомендовано 4GB+)
- **Диск**: 10GB вільного місця
- **CPU**: 1 ядро (рекомендовано 2+)
- **Мережа**: Доступ до інтернету

### Рекомендовані вимоги
- **RAM**: 4GB+
- **Диск**: 50GB+ SSD
- **CPU**: 2+ ядра
- **Мережа**: Статичний IP або домен

## 📖 Детальна інструкція

### Підготовка сервера

1. **Оновлення системи**:
\`\`\`bash
sudo apt update && sudo apt upgrade -y
\`\`\`

2. **Встановлення базових пакетів**:
\`\`\`bash
sudo apt install -y curl wget git
\`\`\`

### Налаштування домену

Перед запуском скрипта налаштуйте DNS-записи:

\`\`\`
# A-запис для основного домену
matrix.example.com -> IP_вашого_сервера

# Або CNAME для піддомену
matrix.example.com -> your-server.example.com
\`\`\`

### Cloudflare Tunnel (рекомендовано)

1. Створіть обліковий запис на [Cloudflare](https://cloudflare.com)
2. Додайте ваш домен до Cloudflare
3. Перейдіть до **Zero Trust** → **Access** → **Tunnels**
4. Створіть новий тунель та скопіюйте токен
5. Використайте токен під час встановлення

### Let's Encrypt SSL

Якщо не використовуєте Cloudflare Tunnel:
1. Переконайтеся, що порти 80 та 443 відкриті
2. Домен повинен вказувати на IP сервера
3. Скрипт автоматично отримає SSL сертифікат

## ⚙️ Конфігурація

### Файли конфігурації

- **Головна конфігурація**: `~/.config/matrix-installer/config.conf`
- **Docker Compose**: `/DATA/matrix/docker-compose.yml`
- **Змінні оточення**: `/DATA/matrix/.env`

### Повторна конфігурація

\`\`\`bash
# Запустити інтерактивну конфігурацію знову
sudo ./install.sh

# Або відредагувати конфігурацію вручну
nano ~/.config/matrix-installer/config.conf
\`\`\`

## 🎛️ Управління системою

### Основні команди

\`\`\`bash
# Статус системи
./bin/matrix-control.sh status

# Запуск/зупинка
./bin/matrix-control.sh start
./bin/matrix-control.sh stop
./bin/matrix-control.sh restart

# Логи
./bin/matrix-control.sh logs
./bin/matrix-control.sh logs synapse

# Оновлення
./bin/matrix-control.sh update

# Резервне копіювання
./bin/matrix-control.sh backup

# Перевірка здоров'я
./bin/matrix-control.sh health
\`\`\`

### Управління користувачами

\`\`\`bash
# Створити користувача
./bin/matrix-control.sh user create admin

# Список користувачів
./bin/matrix-control.sh user list

# Деактивувати користувача
./bin/matrix-control.sh user deactivate username
\`\`\`

## 📊 Моніторинг

### Доступ до сервісів

- **Prometheus**: `http://your-server:9090`
- **Grafana**: `http://your-server:3000` (admin/admin123)
- **Synapse Admin**: `http://your-server:8080`
- **Portainer**: `https://your-server:9443`

### Налаштування алертів

Система автоматично налаштовує алерти для:
- 🔴 Недоступність Synapse
- 🟡 Високе використання пам'яті (>90%)
- 🟡 Високе використання диска (>80%)
- 🔴 Недоступність PostgreSQL

## 💾 Резервне копіювання

### Автоматичні бекапи

\`\`\`bash
# Перевірити статус cron
crontab -l

# Ручний запуск бекапу
./bin/matrix-control.sh backup

# Перегляд логів бекапу
tail -f /DATA/matrix-backups/backup.log
\`\`\`

### Відновлення

\`\`\`bash
# Список доступних бекапів
ls -la /DATA/matrix-backups/

# Відновлення з бекапу
./bin/matrix-control.sh restore matrix-backup-2024-01-01_12-00-00.tar.gz
\`\`\`

## 🌉 Мости

### Підтримувані мости

- **Signal Bridge** - Інтеграція з Signal
- **WhatsApp Bridge** - Інтеграція з WhatsApp  
- **Telegram Bridge** - Інтеграція з Telegram
- **Discord Bridge** - Інтеграція з Discord

### Налаштування мостів

1. Створіть користувача Matrix
2. Увійдіть в Element Web
3. Знайдіть бота моста (`@signalbot:your-domain`)
4. Почніть діалог та слідуйте інструкціям

Детальна інструкція: `/DATA/matrix/docs/BRIDGES.md`

## 🔒 Безпека

### Автоматичні налаштування

- ✅ **UFW Firewall** з мінімальними правилами
- ✅ **Let's Encrypt SSL** (опціонально)
- ✅ **Cloudflare Tunnel** підтримка
- ✅ **Безпечні права доступу** до файлів
- ✅ **Security headers** в Nginx

### Рекомендації

\`\`\`bash
# Регулярні оновлення
sudo apt update && sudo apt upgrade -y
./bin/matrix-control.sh update

# Моніторинг логів
./bin/matrix-control.sh logs synapse | grep -i "error\|warning"

# Перевірка безпеки
./bin/matrix-control.sh health
\`\`\`

## 🔧 Усунення проблем

### Діагностика

\`\`\`bash
# Загальна перевірка здоров'я
./bin/matrix-control.sh health

# Статус сервісів
./bin/matrix-control.sh status

# Логи конкретного сервісу
./bin/matrix-control.sh logs synapse
./bin/matrix-control.sh logs postgres
\`\`\`

### Типові проблеми

#### Synapse не запускається

\`\`\`bash
# Перевірити логи
./bin/matrix-control.sh logs synapse

# Перевірити конфігурацію
docker compose exec synapse python -m synapse.config.homeserver --config-path /data/homeserver.yaml

# Перезапустити
./bin/matrix-control.sh restart
\`\`\`

#### Проблеми з базою даних

\`\`\`bash
# Перевірити статус PostgreSQL
./bin/matrix-control.sh logs postgres

# Підключитися до бази
cd /DATA/matrix
docker compose exec postgres psql -U matrix_user -d matrix_db
\`\`\`

## 📚 Документація

### Локальна документація

Після встановлення доступна в `/DATA/matrix/docs/`:

- `README.md` - Загальна інформація
- `BRIDGES.md` - Налаштування мостів
- `SECURITY.md` - Рекомендації з безпеки
- `TROUBLESHOOTING.md` - Усунення проблем

### Зовнішні ресурси

- [Matrix.org Documentation](https://matrix.org/docs/)
- [Synapse Documentation](https://matrix-org.github.io/synapse/)
- [Element Documentation](https://element.io/help)
- [Mautrix Bridges](https://docs.mau.fi/)

## 🤝 Підтримка

### Отримання допомоги

1. **GitHub Issues**: [Створити issue](https://github.com/your-username/matrix-synapse-installer/issues)
2. **Matrix кімната**: `#matrix-installer:matrix.org`
3. **Документація**: `/DATA/matrix/docs/`

### Внесок у проект

1. Fork репозиторію
2. Створіть feature branch
3. Зробіть зміни з тестами
4. Створіть Pull Request

## 📄 Ліцензія

MIT License - дивіться [LICENSE](LICENSE) для деталей.

## 🙏 Подяки

- Matrix Foundation за протокол
- Команді Synapse за сервер
- Mautrix за мости
- Спільноті за відгуки та внески

---

**⚠️ Важливо**: Завжди робіть резервні копії перед оновленнями!

**🔒 Безпека**: Регулярно оновлюйте систему та моніторьте логи.

**📞 Підтримка**: При проблемах створіть issue з детальним описом та логами.
