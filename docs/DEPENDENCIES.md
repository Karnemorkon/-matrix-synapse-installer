# 📦 Залежності Matrix Synapse Installer

Повний список всіх залежностей, які встановлюються автоматично під час інсталяції.

## 🔧 Системні залежності

### Базові пакети
- **curl** - завантаження файлів та API запити
- **wget** - альтернативне завантаження файлів
- **git** - клонування репозиторіїв
- **apt-transport-https** - підтримка HTTPS для apt
- **ca-certificates** - SSL сертифікати
- **gnupg** - шифрування та підписання
- **lsb-release** - інформація про дистрибутив

### Python залежності
- **python3** - Python 3 інтерпретатор
- **python3-pip** - менеджер пакетів Python
- **python3-venv** - віртуальні середовища Python
- **python3-dev** - заголовочні файли Python
- **build-essential** - інструменти збірки
- **libssl-dev** - SSL бібліотеки
- **libffi-dev** - Foreign Function Interface

### Веб сервери
- **nginx** - веб сервер та reverse proxy
- **supervisor** - управління процесами

### Системні утиліти
- **cron** - планувальник завдань
- **rsync** - синхронізація файлів
- **unzip** - розпакування архівів
- **jq** - обробка JSON
- **net-tools** - мережеві утиліти

## 🛡️ Залежності безпеки

### Файрвол та захист
- **ufw** - Uncomplicated Firewall
- **fail2ban** - захист від брутфорс атак
- **openssl** - SSL/TLS інструменти

### SSL сертифікати
- **certbot** - автоматичне отримання SSL сертифікатів
- **python3-certbot-nginx** - інтеграція Certbot з Nginx

## 🐳 Docker залежності

### Docker Engine
- **docker-ce** - Docker Community Edition
- **docker-ce-cli** - Docker CLI
- **containerd.io** - контейнерний runtime
- **docker-buildx-plugin** - розширена збірка образів
- **docker-compose-plugin** - Docker Compose

## 🌉 Залежності для мостів

### База даних
- **sqlite3** - локальна база даних для мостів

## 📊 Залежності для моніторингу

### Системний моніторинг
- **prometheus-node-exporter** - експорт системних метрик

## 💾 Залежності для резервного копіювання

### Архівування
- **tar** - створення архівів
- **gzip** - стиснення файлів

## 🐍 Python пакети

### Веб API
- **flask** - веб фреймворк
- **flask-cors** - Cross-Origin Resource Sharing
- **pyyaml** - обробка YAML файлів
- **requests** - HTTP клієнт
- **psutil** - системна інформація
- **docker** - Python Docker API

## 🔍 Перевірка залежностей

Скрипт автоматично перевіряє наявність всіх необхідних команд:

```bash
# Список перевіряємих команд
curl wget git python3 pip3 docker docker-compose
nginx supervisord cron rsync unzip jq ufw
fail2ban-client openssl certbot ss ping free df
```

## 📋 Встановлення залежностей

### Автоматичне встановлення
Всі залежності встановлюються автоматично під час запуску:

```bash
./install.sh
```

### Ручне встановлення
Якщо потрібно встановити залежності окремо:

```bash
# Системні пакети
sudo apt update
sudo apt install -y curl wget git python3 python3-pip nginx supervisor

# Docker
curl -fsSL https://get.docker.com | sh

# Python пакети
pip3 install flask flask-cors pyyaml requests psutil docker
```

## 🧹 Очищення

Після встановлення автоматично виконується очищення:

```bash
# Видалення непотрібних пакетів
apt autoremove -y

# Очищення кешу
apt autoclean
```

## 🔧 Розв'язання проблем

### Проблеми з Python пакетами
```bash
# Оновлення pip
python3 -m pip install --upgrade pip

# Встановлення з кешу
pip3 install --no-cache-dir flask flask-cors
```

### Проблеми з Docker
```bash
# Перезапуск Docker
sudo systemctl restart docker

# Перевірка статусу
sudo systemctl status docker
```

### Проблеми з SSL
```bash
# Оновлення сертифікатів
sudo certbot renew

# Перевірка конфігурації Nginx
sudo nginx -t
```

## 📊 Використання ресурсів

### Мінімальні вимоги
- **RAM:** 2 GB (4 GB рекомендовано)
- **Диск:** 10 GB вільного місця
- **CPU:** 1 ядро (2 ядра рекомендовано)

### Рекомендовані вимоги
- **RAM:** 4 GB
- **Диск:** 20 GB SSD
- **CPU:** 2 ядра
- **Мережа:** стабільне інтернет-з'єднання

## 🔄 Оновлення залежностей

### Автоматичне оновлення
```bash
# Оновлення системи
sudo apt update && sudo apt upgrade -y

# Оновлення Python пакетів
pip3 list --outdated | cut -d ' ' -f1 | xargs -n1 pip3 install -U
```

### Оновлення Docker
```bash
# Оновлення Docker образів
docker system prune -a
docker compose pull
```

---

**Примітка:** Всі залежності встановлюються автоматично під час інсталяції. Ручне встановлення потрібно тільки в спеціальних випадках. 