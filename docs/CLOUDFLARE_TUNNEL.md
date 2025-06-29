# 🌐 Cloudflare Tunnel для Matrix Synapse

Детальний гід по налаштуванню Cloudflare Tunnel для безпечного доступу до Matrix Synapse сервера.

## 🎯 Що таке Cloudflare Tunnel?

Cloudflare Tunnel - це сервіс, який дозволяє безпечно підключати сервіси до інтернету без необхідності:
- Публічного IP адреси
- Відкриття портів у файрволі
- Налаштування SSL сертифікатів

## ✅ Переваги використання

- 🔒 **Безпека** - всі з'єднання шифровані
- 🛡️ **DDoS захист** - вбудований в Cloudflare
- 🌍 **Глобальна мережа** - швидкий доступ з будь-якої точки світу
- 🔧 **Простота** - мінімум налаштувань
- 📱 **Мобільний доступ** - працює за NAT

## 🚀 Налаштування Cloudflare Tunnel

### 1. Створення туннелю в Cloudflare Dashboard

1. **Увійдіть в Cloudflare Dashboard**
   - Перейдіть на [dash.cloudflare.com](https://dash.cloudflare.com)
   - Виберіть ваш домен

2. **Створіть туннель**
   - Перейдіть в розділ "Zero Trust" → "Access" → "Tunnels"
   - Натисніть "Create a tunnel"
   - Виберіть "Cloudflared"

3. **Налаштуйте туннель**
   - Введіть назву туннелю (наприклад: "matrix-synapse")
   - Виберіть "Save tunnel"

4. **Отримайте токен**
   - Скопіюйте команду встановлення
   - Виділіть токен з команди (частина після `--token`)

### 2. Налаштування під час встановлення Matrix

Під час запуску `install.sh`:

```bash
# Запуск інсталятора
sudo ./install.sh

# Відповідь на питання про Cloudflare Tunnel
Використовувати Cloudflare Tunnel для доступу? [y/N]: y

# Введення токену
Введіть токен Cloudflare Tunnel: your-tunnel-token-here
```

### 3. Налаштування маршрутів в Cloudflare

Після встановлення налаштуйте маршрути в Cloudflare Dashboard:

1. **Перейдіть до вашого туннелю**
   - Zero Trust → Access → Tunnels → Ваш туннель

2. **Додайте публічні хости**
   - Натисніть "Configure" → "Public Hostnames"
   - Додайте наступні маршрути:

#### Element Web (основний домен)
```
Subdomain: (залиште порожнім для основного домену)
Domain: yourdomain.com
Service: http://localhost:80
```

#### Matrix Synapse API
```
Subdomain: matrix
Domain: yourdomain.com
Service: http://localhost:8008
```

#### Synapse Admin (локальний доступ)
```
Subdomain: admin
Domain: yourdomain.com
Service: http://localhost:8080
```

#### Grafana (локальний доступ)
```
Subdomain: grafana
Domain: yourdomain.com
Service: http://localhost:3000
```

#### Prometheus (локальний доступ)
```
Subdomain: prometheus
Domain: yourdomain.com
Service: http://localhost:9090
```

## 🔧 Перевірка роботи

### Перевірка статусу туннелю
```bash
# Перегляд статусу всіх сервісів
./bin/matrix-control.sh status

# Перегляд логів cloudflared
./bin/matrix-control.sh logs cloudflared
```

### Тестування доступу
```bash
# Тест Element Web (основний домен)
curl -I https://yourdomain.com

# Тест Matrix Synapse API
curl -I https://matrix.yourdomain.com/_matrix/client/versions

# Тест Synapse Admin (локально)
curl -I http://localhost:8080

# Тест Grafana (локально)
curl -I http://localhost:3000

# Тест Prometheus (локально)
curl -I http://localhost:9090
```

## 🛠️ Управління туннелем

### Перезапуск туннелю
```bash
# Перезапуск cloudflared контейнера
./bin/matrix-control.sh restart cloudflared

# Або через Docker Compose
cd /opt/matrix
docker compose restart cloudflared
```

### Оновлення токену
```bash
# Зупинка сервісів
./bin/matrix-control.sh stop

# Редагування .env файлу
nano /opt/matrix/.env

# Змініть CLOUDFLARE_TUNNEL_TOKEN на новий токен

# Запуск сервісів
./bin/matrix-control.sh start
```

## 🔒 Безпека

### Рекомендації
1. **Регулярно оновлюйте токен** - кожні 90 днів
2. **Використовуйте App Policies** - обмежте доступ до сервісів
3. **Моніторте логи** - перевіряйте підозрілу активність
4. **Налаштуйте аутентифікацію** - для адміністративних сервісів

### App Policies в Cloudflare
```bash
# Створіть політику для адміністративних сервісів
# Zero Trust → Access → Applications → Add an application

# Наприклад, для Grafana:
# - Domain: grafana.yourdomain.com
# - Policy: Require authentication
# - Identity providers: Email, Google, etc.
```

## 🐛 Усунення проблем

### Туннель не підключається
```bash
# Перевірте токен
echo $CLOUDFLARE_TUNNEL_TOKEN

# Перевірте логи
docker compose logs cloudflared

# Перевірте підключення до Cloudflare
curl -I https://cloudflare.com
```

### Сервіси недоступні
```bash
# Перевірте локальні сервіси
curl -I http://localhost:8008/_matrix/client/versions

# Перевірте маршрути в Cloudflare Dashboard
# Zero Trust → Access → Tunnels → Ваш туннель → Public Hostnames
```

### Повільне з'єднання
```bash
# Перевірте географічне розташування
# Cloudflare автоматично вибирає найближчий дата-центр

# Можна налаштувати в Cloudflare Dashboard:
# Speed → Optimization → Auto Minify
```

## 📚 Додаткові ресурси

- [Cloudflare Tunnel документація](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Cloudflare Zero Trust](https://developers.cloudflare.com/cloudflare-one/)
- [Matrix.org документація](https://matrix.org/docs/)
- [Synapse документація](https://matrix-org.github.io/synapse/)

## 🔄 Міграція з традиційного SSL

Якщо у вас вже є Matrix сервер з Let's Encrypt:

1. **Створіть Cloudflare Tunnel**
2. **Налаштуйте маршрути**
3. **Тестуйте доступ**
4. **Оновіть DNS записи** (якщо потрібно)
5. **Вимкніть Let's Encrypt** в конфігурації

---

**Примітка:** Cloudflare Tunnel забезпечує безпечний доступ до вашого Matrix сервера без необхідності публічного IP або відкриття портів. 