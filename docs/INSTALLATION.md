# 📋 Гід встановлення Matrix Synapse

Детальні інструкції для встановлення та налаштування Matrix Synapse сервера з підтримкою мостів.

## 📋 Передумови

### Системні вимоги
- **ОС:** Ubuntu 20.04+ або Debian 11+
- **RAM:** 2 GB (мінімум), 4 GB (рекомендовано)
- **Диск:** 10 GB вільного місця
- **Домен:** з правильно налаштованим DNS

### Необхідне програмне забезпечення
- Docker 20.10+
- Docker Compose 2.0+
- Git

## 🚀 Кроки встановлення

### 1. Підготовка системи

```bash
# Оновлення системи
sudo apt update -y && sudo apt upgrade -y

# Встановлення необхідних пакетів
sudo apt install -y git curl wget

# Перевірка версії Docker
docker --version
docker-compose --version
```

### 2. Завантаження інсталятора

```bash
# Клонування репозиторію
git clone https://github.com/Karnemorkon/matrix-synapse-installer.git
cd matrix-synapse-installer

# Надання прав на виконання
chmod +x install.sh
chmod +x bin/matrix-control.sh
```

### 3. Запуск встановлення

```bash
# Запуск інсталятора
sudo ./install.sh
```

Під час встановлення вам буде запропоновано:

- 🌐 **Домен для Matrix сервера** (наприклад: matrix.yourdomain.com)
- 📁 **Базова директорія** (за замовчуванням: /opt/matrix)
- 🔐 **Пароль для PostgreSQL**
- 🌉 **Вибір мостів** (Signal, WhatsApp, Discord)
- 📊 **Налаштування моніторингу**
- 💾 **Конфігурація резервного копіювання**

### 4. Налаштування DNS

Додайте A-запис для вашого домену:

```
matrix.yourdomain.com.  IN  A  YOUR_SERVER_IP
```

### 5. Налаштування SSL сертифікатів

```bash
# Перевірка статусу SSL
./bin/matrix-control.sh ssl check

# Оновлення сертифікатів (якщо потрібно)
./bin/matrix-control.sh ssl renew
```

### 6. Створення адміністратора

```bash
# Створення адміністратора
./bin/matrix-control.sh user create admin
```

## 🔧 Після встановлення

### Перевірка статусу

```bash
# Перегляд статусу всіх сервісів
./bin/matrix-control.sh status

# Перегляд логів
./bin/matrix-control.sh logs
```

### Доступ до сервісів

#### Element Web
- URL: https://yourdomain.com (основний домен)
- Доступ: Публічний доступ через HTTPS

#### Synapse Admin
- URL: http://localhost:8080
- Доступ: Тільки локальний доступ

#### Моніторинг
- Grafana: http://localhost:3000 (локальний доступ)
- Prometheus: http://localhost:9090 (локальний доступ)

### Налаштування мостів

#### Signal Bridge
```bash
# Перевірка статусу Signal мосту
./bin/matrix-control.sh bridge status signal

# Налаштування Signal мосту
./bin/matrix-control.sh bridge setup signal
```

#### WhatsApp Bridge
```bash
# Налаштування WhatsApp мосту
./bin/matrix-control.sh bridge setup whatsapp
```

#### Discord Bridge
```bash
# Налаштування Discord мосту
./bin/matrix-control.sh bridge setup discord
```

### Налаштування файрволу

```bash
# Перевірка налаштувань безпеки
./bin/matrix-control.sh security check
```

## 📊 Моніторинг

### Доступ до Grafana
- URL: http://localhost:3000 (локальний доступ)

### Доступ до Prometheus
- URL: http://localhost:9090 (локальний доступ)

### Доступ до Synapse Admin
- URL: http://localhost:8080 (локальний доступ)

## 💾 Резервне копіювання

### Автоматичне резервне копіювання
```bash
# Створення резервної копії
./bin/matrix-control.sh backup

# Відновлення з резервної копії
./bin/matrix-control.sh restore backup-file.tar.gz
```

## 🔒 Безпека

### Рекомендовані налаштування
1. Змініть паролі за замовчуванням
2. Налаштуйте файрвол
3. Регулярно оновлюйте систему
4. Моніторте логи безпеки

### Перевірка безпеки
```bash
# Перевірка налаштувань безпеки
./bin/matrix-control.sh security audit
```

## 🐛 Усунення проблем

### Поширені проблеми

#### Проблеми з Docker
```bash
# Перезапуск Docker
sudo systemctl restart docker

# Очищення Docker
docker system prune -a
```

#### Проблеми з SSL
```bash
# Перевірка SSL сертифікатів
./bin/matrix-control.sh ssl check

# Оновлення сертифікатів
./bin/matrix-control.sh ssl renew
```

#### Проблеми з мостами
```bash
# Перезапуск мосту
./bin/matrix-control.sh bridge restart signal

# Перегляд логів мосту
./bin/matrix-control.sh bridge logs signal
```

### Отримання допомоги

1. Перевірте [документацію з усунення проблем](TROUBLESHOOTING.md)
2. Пошукайте в [існуючих issues](https://github.com/Karnemorkon/matrix-synapse-installer/issues)
3. Створіть нове issue з детальним описом проблеми

## 📚 Додаткові ресурси

- [Matrix.org документація](https://matrix.org/docs/)
- [Synapse документація](https://matrix-org.github.io/synapse/)
- [Mautrix мости](https://github.com/mautrix)
- [Element клієнт](https://element.io/)

---

**Примітка:** Цей гід призначений для базового встановлення. Для продакшн середовища рекомендується додаткове налаштування безпеки та моніторингу. 