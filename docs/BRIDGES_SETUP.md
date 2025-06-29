# 🌉 Налаштування мостів Matrix

## 📋 Огляд

Мости дозволяють інтегрувати Matrix з іншими месенджерами та сервісами. Після встановлення кожен міст потребує додаткового налаштування.

## 🚀 Швидкий старт

### 1. Перевірка встановлених мостів

```bash
# Перевірити які мости встановлені
ls -la /DATA/matrix/bridges/

# Перевірити статус мостів
./bin/matrix-control.sh status
```

### 2. Загальний процес налаштування

Для кожного моста потрібно:

1. **Налаштувати конфігурацію** в `bridges/<bridge-name>/config/config.yaml`
2. **Зареєструвати міст** в Synapse
3. **Запустити міст** та завершити налаштування
4. **Протестувати** функціональність

## 📱 Signal Bridge

### Налаштування

1. **Встановіть Signal на телефон**
2. **Запустіть signald:**
   ```bash
   docker run -d --name signald \
     -v /DATA/matrix/bridges/signal/data:/signald \
     finn/signald
   ```

3. **Зареєструйте пристрій:**
   ```bash
   docker exec signald signald-cli -a +YOUR_PHONE_NUMBER register
   ```

4. **Налаштуйте конфігурацію:**
   ```bash
   nano /DATA/matrix/bridges/signal/config/config.yaml
   ```

5. **Запустіть міст:**
   ```bash
   cd /DATA/matrix
   docker compose up -d signal-bridge
   ```

### Команди

- `!signal help` - Показати допомогу
- `!signal login` - Увійти в Signal
- `!signal logout` - Вийти з Signal
- `!signal sync` - Синхронізувати контакти

## 💬 WhatsApp Bridge

### Налаштування

1. **Налаштуйте конфігурацію:**
   ```bash
   nano /DATA/matrix/bridges/whatsapp/config/config.yaml
   ```

2. **Запустіть міст:**
   ```bash
   cd /DATA/matrix
   docker compose up -d whatsapp-bridge
   ```

3. **Відскануйте QR-код** з вашого телефону

### Команди

- `!wa help` - Показати допомогу
- `!wa login` - Увійти в WhatsApp
- `!wa logout` - Вийти з WhatsApp
- `!wa sync` - Синхронізувати контакти

## 🎮 Discord Bridge

### Налаштування

1. **Створіть Discord бота:**
   - Відвідайте https://discord.com/developers/applications
   - Створіть новий додаток
   - Додайте бота до додатку
   - Скопіюйте токен бота

2. **Налаштуйте конфігурацію:**
   ```bash
   nano /DATA/matrix/bridges/discord/config/config.yaml
   ```

3. **Запустіть міст:**
   ```bash
   cd /DATA/matrix
   docker compose up -d discord-bridge
   ```

### Команди

- `!discord help` - Показати допомогу
- `!discord login` - Увійти в Discord
- `!discord logout` - Вийти з Discord
- `!discord sync` - Синхронізувати сервери

## 🔧 Управління мостами

### Перевірка статусу

```bash
# Статус всіх мостів
./bin/matrix-control.sh status

# Логи конкретного моста
./bin/matrix-control.sh bridge logs signal
./bin/matrix-control.sh bridge logs whatsapp
```

### Перезапуск мостів

```bash
# Перезапустити всі мости
cd /DATA/matrix
docker compose restart *-bridge

# Перезапустити конкретний міст
docker compose restart signal-bridge
```

### Оновлення мостів

```bash
# Оновити всі образи мостів
cd /DATA/matrix
docker compose pull *-bridge
docker compose up -d *-bridge
```

## 🐛 Усунення проблем

### Загальні проблеми

#### Міст не запускається

```bash
# Перевірити логи
./bin/matrix-control.sh bridge logs <bridge-name>

# Перевірити конфігурацію
cat /DATA/matrix/bridges/<bridge-name>/config/config.yaml

# Перевірити права доступу
ls -la /DATA/matrix/bridges/<bridge-name>/
```

#### Проблеми з підключенням

```bash
# Перевірити мережеві з'єднання
docker compose exec <bridge-name>-bridge ping google.com

# Перевірити порти
netstat -tlnp | grep <bridge-port>
```

#### Проблеми з автентифікацією

```bash
# Перевірити токени та ключі
grep -r "token\|key" /DATA/matrix/bridges/<bridge-name>/config/

# Перезапустити міст
docker compose restart <bridge-name>-bridge
```

### Специфічні проблеми

#### Signal Bridge
- Перевірте чи запущений signald
- Перевірте правильність номера телефону
- Перевірте підключення до Signal серверів

#### WhatsApp Bridge
- Перевірте QR-код
- Перевірте підключення до WhatsApp Web
- Перевірте налаштування браузера

#### Discord Bridge
- Перевірте токен бота
- Перевірте права доступу бота
- Перевірте підключення до Discord API

## 📚 Додаткові ресурси

### Офіційна документація
- [Mautrix Bridges](https://docs.mau.fi/bridges/)
- [Signal Bridge](https://docs.mau.fi/bridges/python/signal/)
- [WhatsApp Bridge](https://docs.mau.fi/bridges/python/whatsapp/)
- [Discord Bridge](https://docs.mau.fi/bridges/python/discord/)

### Спільнота
- [Matrix Bridge Support](https://matrix.to/#/#bridges:maunium.net)
- [GitHub Issues](https://github.com/mautrix/bridges/issues)

---

**Останнє оновлення:** $(date)
**Версія документа:** 1.0 