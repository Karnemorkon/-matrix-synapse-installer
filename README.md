# Matrix Synapse Auto Installer 3.0

🚀 **Автоматизований інсталятор Matrix Synapse з модульною архітектурою**

[![Version](https://img.shields.io/badge/Version-3.0-blue.svg)](https://github.com/your-username/matrix-synapse-installer)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

## 🎯 Особливості

### 🏗️ Модульна архітектура
- **Розділені модулі** для кожної функціональності
- **Централізоване логування** з різними рівнями
- **Конфігураційна система** з валідацією
- **Покращена обробка помилок**

### 🔧 Автоматизація
- **Інтерактивний скрипт управління** `matrix-control.sh`
- **Автоматична валідація** системних вимог
- **Розширена діагностика** здоров'я системи
- **Централізоване управління користувачами**

### 📊 Моніторинг
- **Prometheus + Grafana** з готовими дашбордами
- **Системні метрики** через Node Exporter
- **Метрики Matrix Synapse**

### 💾 Резервне копіювання
- **Автоматичні бекапи** з ротацією
- **Консистентні бекапи** з зупинкою сервісів
- **Гнучкий розклад** (щодня о 2:00)

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

## 🚀 Швидкий старт

### 1. Завантаження

```bash
git clone https://github.com/your-username/matrix-synapse-installer.git
cd matrix-synapse-installer
chmod +x install.sh
```

### 2. Запуск встановлення

```bash
sudo ./install.sh
```

### 3. Слідування майстру встановлення

Скрипт проведе вас через всі необхідні кроки:
- ✅ Перевірка системних вимог
- ⚙️ Інтерактивна конфігурація
- 🔐 Налаштування безпеки
- 🐳 Встановлення Docker сервісів
- 📊 Налаштування моніторингу
- 💾 Система резервного копіювання

## 🎛️ Управління системою

### Основні команди

```bash
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
```

### Управління користувачами

```bash
# Створити користувача
./bin/matrix-control.sh user create admin

# Список користувачів
./bin/matrix-control.sh user list
```

## 📊 Доступ до сервісів

Після встановлення будуть доступні:

- **Matrix Synapse**: `http://your-server:8008`
- **Synapse Admin**: `http://your-server:8080`
- **Element Web**: `http://your-server:80` (якщо встановлено)
- **Grafana**: `http://your-server:3000` (admin/admin123, якщо увімкнено)
- **Prometheus**: `http://your-server:9090` (якщо увімкнено)

## 🔒 Безпека

### Автоматичні налаштування

- ✅ **UFW Firewall** з мінімальними правилами
- ✅ **Безпечні права доступу** до файлів
- ✅ **Security headers** в конфігурації

### Рекомендації

```bash
# Регулярні оновлення
sudo apt update && sudo apt upgrade -y
./bin/matrix-control.sh update

# Моніторинг логів
./bin/matrix-control.sh logs synapse | grep -i "error\|warning"

# Перевірка безпеки
./bin/matrix-control.sh health
```

## 💾 Резервне копіювання

### Автоматичні бекапи

```bash
# Перевірити статус cron
crontab -l

# Ручний запуск бекапу
./bin/matrix-control.sh backup

# Перегляд логів бекапу
tail -f /DATA/matrix-backups/backup.log
```

## 🔧 Усунення проблем

### Діагностика

```bash
# Загальна перевірка здоров'я
./bin/matrix-control.sh health

# Статус сервісів
./bin/matrix-control.sh status

# Логи конкретного сервісу
./bin/matrix-control.sh logs synapse
./bin/matrix-control.sh logs postgres
```

### Типові проблеми

#### Synapse не запускається

```bash
# Перевірити логи
./bin/matrix-control.sh logs synapse

# Перезапустити
./bin/matrix-control.sh restart
```

## 🤝 Підтримка

### Отримання допомоги

1. **GitHub Issues**: [Створити issue](https://github.com/your-username/matrix-synapse-installer/issues)
2. **Документація**: Перевірте локальну документацію після встановлення

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
- Спільноті за відгуки та внески

---

**⚠️ Важливо**: Завжди робіть резервні копії перед оновленнями!

**🔒 Безпека**: Регулярно оновлюйте систему та моніторьте логи.

**📞 Підтримка**: При проблемах створіть issue з детальним описом та логами.
