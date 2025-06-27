# Усунення проблем Matrix Synapse

## 🔍 Загальна діагностика

### Перевірка здоров'я системи

\`\`\`bash
# Загальна перевірка
./bin/matrix-control.sh health

# Статус всіх сервісів
./bin/matrix-control.sh status

# Використання ресурсів
docker stats --no-stream
\`\`\`

### Перевірка логів

\`\`\`bash
# Логи всіх сервісів
./bin/matrix-control.sh logs

# Логи конкретного сервісу
./bin/matrix-control.sh logs synapse
./bin/matrix-control.sh logs postgres

# Логи з фільтрацією
./bin/matrix-control.sh logs synapse | grep -i error
./bin/matrix-control.sh logs synapse | grep -i warning
\`\`\`

## 🚨 Типові проблеми

### 1. Synapse не запускається

#### Симптоми:
- Сервіс постійно перезапускається
- Помилки в логах при запуску
- Недоступність API на порту 8008

#### Діагностика:
\`\`\`bash
# Перевірити логи Synapse
./bin/matrix-control.sh logs synapse

# Перевірити права доступу
ls -la /DATA/matrix/synapse/config/
ls -la /DATA/matrix/synapse/data/
\`\`\`

#### Рішення:
\`\`\`bash
# Виправити права доступу
sudo chown -R 991:991 /DATA/matrix/synapse/

# Перезапустити сервіс
./bin/matrix-control.sh restart
\`\`\`

### 2. Проблеми з базою даних PostgreSQL

#### Симптоми:
- Synapse не може підключитися до бази
- Помилки "connection refused"
- Повільна робота системи

#### Діагностика:
\`\`\`bash
# Перевірити статус PostgreSQL
./bin/matrix-control.sh logs postgres

# Перевірити підключення
cd /DATA/matrix
docker compose exec postgres pg_isready -U matrix_user
\`\`\`

#### Рішення:
\`\`\`bash
# Перезапустити PostgreSQL
docker compose restart postgres

# Перевірити дисковий простір
df -h /DATA/matrix/
\`\`\`

### 3. Проблеми з мостами

#### Симптоми:
- Мости не відповідають на команди
- Повідомлення не синхронізуються
- Помилки автентифікації

#### Діагностика:
\`\`\`bash
# Перевірити логи мостів
./bin/matrix-control.sh logs signal-bridge
./bin/matrix-control.sh logs whatsapp-bridge

# Перевірити реєстраційні файли
ls -la /DATA/matrix/*/config/registration.yaml

# Перевірити конфігурацію в homeserver.yaml
grep -A 10 "app_service_config_files:" /DATA/matrix/synapse/config/homeserver.yaml
\`\`\`

#### Рішення:
\`\`\`bash
# Перегенерувати реєстраційні файли
cd /DATA/matrix
docker compose exec synapse generate_registration \
  --force \
  -u "http://signal-bridge:8000" \
  -c "/data/signal-registration.yaml" \
  "io.mau.bridge.signal"

# Перезапустити мости
docker compose restart signal-bridge whatsapp-bridge

# Перезапустити Synapse
docker compose restart synapse
\`\`\`

### 4. Проблеми з SSL/HTTPS

#### Симптоми:
- Сертифікат прострочений
- Помилки SSL в браузері
- Федерація не працює

#### Діагностика:
\`\`\`bash
# Перевірити статус сертифікатів
sudo certbot certificates

# Перевірити конфігурацію Nginx
sudo nginx -t

# Перевірити логи Nginx
sudo tail -f /var/log/nginx/error.log
\`\`\`

#### Рішення:
\`\`\`bash
# Оновити сертифікати
sudo certbot renew

# Перезапустити Nginx
sudo systemctl restart nginx

# Перевірити автоматичне оновлення
sudo certbot renew --dry-run
\`\`\`

### 5. Проблеми з продуктивністю

#### Симптоми:
- Повільна робота інтерфейсу
- Високе використання CPU/RAM
- Тайм-аути запитів

#### Діагностика:
\`\`\`bash
# Перевірити використання ресурсів
docker stats --no-stream

# Перевірити дисковий простір
df -h

# Перевірити пам'ять
free -h

# Перевірити активні з'єднання
docker compose exec postgres psql -U matrix_user -d matrix_db -c "SELECT count(*) FROM pg_stat_activity;"
\`\`\`

#### Рішення:
\`\`\`bash
# Очистити кеш Synapse
docker compose exec synapse python -m synapse.app.admin_cmd -c /data/homeserver.yaml purge_history

# Оптимізувати базу даних
docker compose exec postgres psql -U matrix_user -d matrix_db -c "VACUUM ANALYZE;"

# Перезапустити сервіси
./bin/matrix-control.sh restart
\`\`\`

## 🔧 Інструменти діагностики

### Корисні команди Docker

\`\`\`bash
# Перевірити використання дискового простору Docker
docker system df

# Очистити невикористані ресурси
docker system prune -f

# Перевірити логи конкретного контейнера
docker logs matrix-synapse-1 --tail 100

# Увійти в контейнер для діагностики
docker compose exec synapse bash
\`\`\`

### Перевірка мережі

\`\`\`bash
# Перевірити відкриті порти
netstat -tuln | grep -E "(8008|8448|80|443)"

# Перевірити підключення до Synapse
curl -I http://localhost:8008/_matrix/client/versions

# Перевірити федерацію
curl -I https://your-domain.com/_matrix/federation/v1/version
\`\`\`

### Моніторинг в реальному часі

\`\`\`bash
# Моніторинг логів в реальному часі
./bin/matrix-control.sh logs synapse | grep -E "(ERROR|WARN)"

# Моніторинг використання ресурсів
watch -n 5 'docker stats --no-stream'

# Моніторинг дискового простору
watch -n 10 'df -h /DATA/matrix'
\`\`\`

## 🆘 Екстрені процедури

### Повне відновлення системи

\`\`\`bash
# 1. Зупинити всі сервіси
./bin/matrix-control.sh stop

# 2. Відновити з останнього бекапу (якщо доступний)
# Розпакувати бекап та відновити файли

# 3. Запустити сервіси
./bin/matrix-control.sh start
\`\`\`

### Скидання паролів

\`\`\`bash
# Скинути пароль користувача Matrix
cd /DATA/matrix
docker compose exec synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u existing_user \
  -p new_password \
  --no-admin \
  http://localhost:8008
\`\`\`

### Очищення даних

\`\`\`bash
# Очистити старі медіа файли (старші 30 днів)
docker compose exec synapse python -m synapse.app.admin_cmd \
  -c /data/homeserver.yaml \
  delete_old_media \
  --before-ts $(date -d '30 days ago' +%s)000

# Очистити старі логи
find /DATA/matrix/logs -name "*.log" -mtime +7 -delete
\`\`\`

## 📞 Отримання допомоги

### Збір інформації для звернення

\`\`\`bash
# Створити звіт про систему
{
  echo "=== System Info ==="
  uname -a
  echo
  echo "=== Docker Version ==="
  docker --version
  docker compose version
  echo
  echo "=== Service Status ==="
  ./bin/matrix-control.sh status
  echo
  echo "=== Health Check ==="
  ./bin/matrix-control.sh health
  echo
  echo "=== Recent Logs ==="
  ./bin/matrix-control.sh logs synapse --tail 50
} > matrix-debug-report.txt
\`\`\`

### Контакти для підтримки

- **GitHub Issues**: Створіть issue з debug звітом
- **Документація**: Перевірте README.md

### Корисні посилання

- [Matrix Troubleshooting Guide](https://matrix.org/docs/guides/troubleshooting)
- [Synapse Documentation](https://matrix-org.github.io/synapse/)
- [Docker Troubleshooting](https://docs.docker.com/config/troubleshooting/)
