# 🧪 Тестування Matrix Synapse Installer

## 📋 Огляд тестування

Цей каталог містить тести для перевірки функціональності Matrix Synapse Installer.

## 🚀 Швидкий старт

### Запуск всіх тестів

```bash
# Запустити тести як root (потрібно для повного тестування)
sudo ./tests/test-installation.sh
```

### Запуск окремих тестів

```bash
# Тестування системних вимог
sudo ./tests/test-installation.sh system-requirements

# Тестування конфігурації
sudo ./tests/test-installation.sh configuration

# Тестування Docker
sudo ./tests/test-installation.sh docker
```

## 📊 Типи тестів

### 1. **Функціональні тести**
- Перевірка системних вимог
- Валідація конфігурації
- Генерація файлів конфігурації
- Управління сервісами

### 2. **Інтеграційні тести**
- Встановлення Docker
- Запуск контейнерів
- Перевірка API
- Тестування бази даних

### 3. **Тести безпеки**
- Перевірка прав доступу
- Валідація SSL сертифікатів
- Налаштування файрволу

### 4. **Тести продуктивності**
- Перевірка використання ресурсів
- Тестування резервного копіювання
- Моніторинг логів

## 🔧 Налаштування тестового середовища

### Вимоги для тестування

```bash
# Системні вимоги
- Ubuntu 20.04+ або Debian 11+
- Мінімум 4GB RAM
- 20GB вільного дискового простору
- Root права доступу
- Інтернет-з'єднання
```

### Підготовка середовища

```bash
# Встановлення залежностей
sudo apt update
sudo apt install -y curl docker.io docker-compose

# Запуск Docker
sudo systemctl start docker
sudo systemctl enable docker

# Додавання користувача до групи docker
sudo usermod -aG docker $USER
```

## 📈 Метрики тестування

### Ключові показники

- **Покриття тестами:** > 80%
- **Час виконання тестів:** < 10 хвилин
- **Успішність тестів:** > 95%
- **Час відновлення:** < 5 хвилин

### Результати тестування

```bash
# Приклад виводу
[2024-01-01 12:00:00] Starting Matrix Synapse Installer Test Suite
[SUCCESS] Tests passed: 15
[ERROR] Tests failed: 0
[INFO] Total tests: 15
[INFO] Success rate: 100%
[SUCCESS] All tests passed!
```

## 🐛 Усунення проблем

### Типові проблеми

#### 1. **Помилки прав доступу**
```bash
# Рішення: Запустити як root
sudo ./tests/test-installation.sh
```

#### 2. **Проблеми з Docker**
```bash
# Перевірити статус Docker
sudo systemctl status docker

# Перезапустити Docker
sudo systemctl restart docker
```

#### 3. **Недостатньо ресурсів**
```bash
# Перевірити доступні ресурси
free -h
df -h

# Збільшити swap якщо потрібно
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### 4. **Проблеми з мережею**
```bash
# Перевірити з'єднання
ping -c 3 8.8.8.8

# Перевірити DNS
nslookup google.com
```

## 🔄 Неперервна інтеграція

### Локальне тестування

```bash
# Запуск тестів перед комітом
./tests/test-installation.sh

# Запуск тестів з детальним виводом
DEBUG=true ./tests/test-installation.sh
```

## 📚 Додаткові ресурси

### Корисні команди

```bash
# Перевірка логів тестів
tail -f /tmp/matrix-test/installer/logs/test.log

# Очищення тестового середовища
sudo ./tests/cleanup.sh

# Генерація звіту про тести
./tests/generate-report.sh
```

### Документація

- [Matrix Synapse Documentation](https://matrix-org.github.io/synapse/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Bash Testing Best Practices](https://github.com/kward/shunit2)

## 🧪 Тестування залежностей

### Перевірка залежностей
```bash
# Запуск тесту залежностей
./tests/test-dependencies.sh

# Приклад виводу
🧪 Тест залежностей Matrix Synapse Installer
==============================================
[INFO] Перевірка всіх команд...
[SUCCESS] curl - доступний
[SUCCESS] wget - доступний
[SUCCESS] docker - доступний
...
[INFO] Перевірка Python пакетів...
[SUCCESS] Python пакет flask - встановлено
[SUCCESS] Python пакет flask-cors - встановлено
...
==============================================
📊 Результати тестування:
   Пройдено тестів: 2/2
   Успішність: 100%
[SUCCESS] Всі тести пройдено успішно! ✅
```

### Що перевіряється
- **Системні команди:** curl, wget, git, docker, nginx, ufw, fail2ban, certbot
- **Python пакети:** flask, flask-cors, pyyaml, requests, psutil, docker
- **Версії програм:** Python 3.8+, Docker 20.10+
- **Системні ресурси:** RAM, дисковий простір
- **Мережеве з'єднання:** доступність зовнішніх серверів

---

**Останнє оновлення:** $(date)
**Версія документа:** 1.0 