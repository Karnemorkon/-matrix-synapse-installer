# 📚 Документація Matrix Synapse Installer

Ласкаво просимо до документації проекту Matrix Synapse Installer - автоматизованого інсталятора для Matrix Synapse сервера з підтримкою мостів, моніторингу та резервного копіювання.

## 📋 Зміст

### 🚀 Початок роботи
- [📋 Гід встановлення](INSTALLATION.md) - детальні інструкції встановлення
- [🌐 Cloudflare Tunnel](CLOUDFLARE_TUNNEL.md) - налаштування безпечного доступу

### 🌉 Мости та інтеграції
- [🌉 Налаштування мостів](BRIDGES_SETUP.md) - конфігурація Signal, WhatsApp, Discord мостів

### 🔧 Управління та обслуговування
- [🔧 Усунення проблем](TROUBLESHOOTING.md) - рішення поширених проблем

## 🎯 Швидкий доступ

### Основні команди
```bash
# Встановлення
sudo ./install.sh

# Управління
./bin/matrix-control.sh status
./bin/matrix-control.sh start
./bin/matrix-control.sh stop

# Користувачі
./bin/matrix-control.sh user create admin
./bin/matrix-control.sh user list

# Мости
./bin/matrix-control.sh bridge list
./bin/matrix-control.sh bridge setup signal

# Резервне копіювання
./bin/matrix-control.sh backup
./bin/matrix-control.sh restore backup-file.tar.gz
```

### Доступ до сервісів
- **Element Web**: https://yourdomain.com
- **Matrix API**: https://yourdomain.com/_matrix
- **Synapse Admin**: http://localhost:8080 (локальний)
- **Grafana**: http://localhost:3000 (локальний)
- **Prometheus**: http://localhost:9090 (локальний)

## 🏗️ Архітектура проекту

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
```

## 🔧 Налаштування

### Системні вимоги
- **ОС:** Ubuntu 20.04+ або Debian 11+
- **RAM:** 2 GB (мінімум), 4 GB (рекомендовано)
- **Диск:** 10 GB вільного місця
- **Docker:** версія 20.10+
- **Docker Compose:** версія 2.0+
- **Домен:** з правильно налаштованим DNS

### Підтримувані мости
- 📱 **Signal Bridge** - інтеграція з Signal месенджером
- 💬 **WhatsApp Bridge** - інтеграція з WhatsApp
- 🎮 **Discord Bridge** - інтеграція з Discord серверами

## 🛡️ Безпека

### Рекомендації
1. **Регулярно оновлюйте систему** - автоматичні оновлення безпеки
2. **Використовуйте сильні паролі** - автоматична генерація безпечних паролів
3. **Налаштуйте файрвол** - UFW з обмеженням швидкості
4. **Моніторте логи** - відстеження підозрілої активності
5. **Резервне копіювання** - автоматичні бекапи

### Cloudflare Tunnel
Для додаткової безпеки рекомендується використовувати Cloudflare Tunnel:
- Без публічного IP
- Автоматичне SSL шифрування
- DDoS захист
- Глобальна мережа

## 🐛 Підтримка

### Отримання допомоги
1. Перевірте [документацію з усунення проблем](TROUBLESHOOTING.md)
2. Пошукайте в [існуючих issues](https://github.com/Karnemorkon/matrix-synapse-installer/issues)
3. Створіть нове issue з детальним описом проблеми

### Корисні команди для діагностики
```bash
# Перегляд статусу
./bin/matrix-control.sh status

# Перегляд логів
./bin/matrix-control.sh logs

# Перевірка конфігурації
./bin/matrix-control.sh config check

# Тестування з'єднань
./bin/matrix-control.sh test connectivity
```

## 📚 Додаткові ресурси

### Офіційна документація
- [Matrix.org](https://matrix.org/docs/) - офіційна документація Matrix
- [Synapse](https://matrix-org.github.io/synapse/) - документація Synapse
- [Mautrix](https://github.com/mautrix) - документація мостів
- [Element](https://element.io/) - документація клієнта

### Спільнота
- [Matrix Chat](https://matrix.org/community) - спільнота Matrix
- [GitHub Discussions](https://github.com/Karnemorkon/matrix-synapse-installer/discussions) - обговорення проекту

## 🤝 Внесок

Ми вітаємо внески! Будь ласка:
1. Форк репозиторію
2. Створіть гілку для нової функції
3. Зробіть коміт змін
4. Створіть Pull Request

### Вимоги до коду
- Дотримуйтесь стилю коду
- Додайте тести для нової функціональності
- Оновіть документацію
- Перевірте, що всі тести проходять

---

**Версія документації:** 3.0  
**Останнє оновлення:** $(date)  
**Автор:** Matrix Synapse Installer Team 