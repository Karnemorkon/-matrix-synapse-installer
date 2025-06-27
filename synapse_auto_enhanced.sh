#!/bin/bash
# ===================================================================================
#
# Покращений інтерактивний скрипт для встановлення Matrix Synapse
# Версія: 2.0 Enhanced
# ===================================================================================

# Зупинити виконання скрипту, якщо виникне помилка
set -e

# --- Налаштування логування ---
LOG_DIR_PATH_FOR_SCRIPT=$(pwd)
LOG_FILENAME_FOR_SCRIPT="matrix_install_$(date +%Y-%m-%d_%H-%M-%S).log"
FULL_LOG_PATH_FOR_SCRIPT="$LOG_DIR_PATH_FOR_SCRIPT/$LOG_FILENAME_FOR_SCRIPT"

# Функція для виводу повідомлення на екран та в лог
log_echo() {
    echo "$@" # Вивід на екран
    if [ -n "$FULL_LOG_PATH_FOR_SCRIPT" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $@" >> "$FULL_LOG_PATH_FOR_SCRIPT"
    fi
}

# --- Функція валідації системних вимог ---
validate_system_requirements() {
    log_echo "--- Перевірка системних вимог ---"
    
    # Перевірка RAM
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))
    MIN_RAM_GB=2
    
    log_echo "Доступна оперативна пам'ять: ${TOTAL_RAM_GB}GB"
    if [ $TOTAL_RAM_GB -lt $MIN_RAM_GB ]; then
        log_echo "⚠️ Попередження: Рекомендується мінімум ${MIN_RAM_GB}GB RAM для стабільної роботи Matrix Synapse."
        log_echo "Поточна кількість: ${TOTAL_RAM_GB}GB може бути недостатньою для великих серверів."
        read -p "Продовжити встановлення? (yes/no) [no]: " CONTINUE_LOW_RAM
        CONTINUE_LOW_RAM=${CONTINUE_LOW_RAM:-no}
        if [ "$CONTINUE_LOW_RAM" != "yes" ]; then
            log_echo "❌ Встановлення скасовано через недостатню кількість RAM."
            exit 1
        fi
    else
        log_echo "✅ RAM: достатньо (${TOTAL_RAM_GB}GB >= ${MIN_RAM_GB}GB)"
    fi
    
    # Перевірка дискового простору
    AVAILABLE_SPACE_KB=$(df / | tail -1 | awk '{print $4}')
    AVAILABLE_SPACE_GB=$((AVAILABLE_SPACE_KB / 1024 / 1024))
    MIN_SPACE_GB=10
    
    log_echo "Доступний дисковий простір: ${AVAILABLE_SPACE_GB}GB"
    if [ $AVAILABLE_SPACE_GB -lt $MIN_SPACE_GB ]; then
        log_echo "❌ Помилка: Недостатньо дискового простору. Потрібно мінімум ${MIN_SPACE_GB}GB."
        log_echo "Доступно: ${AVAILABLE_SPACE_GB}GB"
        exit 1
    else
        log_echo "✅ Дисковий простір: достатньо (${AVAILABLE_SPACE_GB}GB >= ${MIN_SPACE_GB}GB)"
    fi
    
    # Перевірка архітектури процесора
    ARCH=$(uname -m)
    log_echo "Архітектура процесора: $ARCH"
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
        log_echo "⚠️ Попередження: Непідтримувана архітектура процесора: $ARCH"
        log_echo "Docker образи можуть не працювати коректно."
    else
        log_echo "✅ Архітектура процесора: підтримується ($ARCH)"
    fi
    
    # Перевірка версії ядра Linux
    KERNEL_VERSION=$(uname -r)
    log_echo "Версія ядра Linux: $KERNEL_VERSION"
    
    log_echo "✅ Перевірка системних вимог завершена."
}

# --- Функція налаштування автоматичного резервного копіювання ---
setup_backup_system() {
    log_echo "--- Налаштування системи резервного копіювання ---"
    
    while true; do
        read -p "Налаштувати автоматичне резервне копіювання? (yes/no) [yes]: " SETUP_BACKUP
        SETUP_BACKUP=${SETUP_BACKUP:-yes}
        case "$SETUP_BACKUP" in
            yes|no) break;;
            *) echo "Некоректний вибір. Будь ласка, введіть 'yes' або 'no'.";;
        esac
    done
    
    if [ "$SETUP_BACKUP" = "yes" ]; then
        # Створюємо директорію для бекапів
        BACKUP_DIR="/DATA/matrix-backups"
        mkdir -p "$BACKUP_DIR"
        
        # Створюємо скрипт резервного копіювання
        cat > "$BACKUP_DIR/backup-matrix.sh" << 'EOF'
#!/bin/bash
# Скрипт автоматичного резервного копіювання Matrix Synapse

BACKUP_DIR="/DATA/matrix-backups"
MATRIX_DIR="/DATA/matrix"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="matrix-backup-$DATE"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Створюємо директорію для поточного бекапу
mkdir -p "$BACKUP_PATH"

# Логування
echo "$(date): Початок резервного копіювання Matrix" >> "$BACKUP_DIR/backup.log"

# Зупиняємо контейнери для консистентного бекапу
cd "$MATRIX_DIR"
docker compose stop

# Копіюємо конфігурації
cp -r "$MATRIX_DIR/synapse/config" "$BACKUP_PATH/"
cp -r "$MATRIX_DIR/synapse/data" "$BACKUP_PATH/" 2>/dev/null || true

# Копіюємо конфігурації мостів
for bridge in signal-bridge whatsapp-bridge telegram-bridge discord-bridge; do
    if [ -d "$MATRIX_DIR/$bridge" ]; then
        cp -r "$MATRIX_DIR/$bridge" "$BACKUP_PATH/"
    fi
done

# Копіюємо docker-compose.yml та .env
cp "$MATRIX_DIR/docker-compose.yml" "$BACKUP_PATH/" 2>/dev/null || true
cp "$MATRIX_DIR/.env" "$BACKUP_PATH/" 2>/dev/null || true

# Бекап бази даних PostgreSQL
docker compose start postgres
sleep 10
docker compose exec -T postgres pg_dump -U matrix_user matrix_db > "$BACKUP_PATH/database.sql"

# Запускаємо контейнери назад
docker compose up -d

# Архівуємо бекап
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Видаляємо старі бекапи (зберігаємо останні 7)
find "$BACKUP_DIR" -name "matrix-backup-*.tar.gz" -type f -mtime +7 -delete

echo "$(date): Резервне копіювання завершено: $BACKUP_NAME.tar.gz" >> "$BACKUP_DIR/backup.log"
EOF

        chmod +x "$BACKUP_DIR/backup-matrix.sh"
        
        # Налаштовуємо cron для автоматичного бекапу
        while true; do
            echo "Оберіть частоту автоматичного резервного копіювання:"
            echo "1) Щодня о 2:00"
            echo "2) Щотижня (неділя о 2:00)"
            echo "3) Вручну (без автоматизації)"
            read -p "Ваш вибір (1-3) [1]: " BACKUP_FREQUENCY
            BACKUP_FREQUENCY=${BACKUP_FREQUENCY:-1}
            case $BACKUP_FREQUENCY in
                1|2|3) break;;
                *) echo "Некоректний вибір. Будь ласка, введіть 1, 2 або 3.";;
            esac
        done
        
        case $BACKUP_FREQUENCY in
            1)
                # Щодня о 2:00
                (crontab -l 2>/dev/null; echo "0 2 * * * $BACKUP_DIR/backup-matrix.sh") | crontab -
                log_echo "✅ Налаштовано щоденне резервне копіювання о 2:00"
                ;;
            2)
                # Щотижня в неділю о 2:00
                (crontab -l 2>/dev/null; echo "0 2 * * 0 $BACKUP_DIR/backup-matrix.sh") | crontab -
                log_echo "✅ Налаштовано щотижневе резервне копіювання (неділя о 2:00)"
                ;;
            3)
                log_echo "✅ Скрипт резервного копіювання створено: $BACKUP_DIR/backup-matrix.sh"
                log_echo "Для ручного запуску використовуйте: $BACKUP_DIR/backup-matrix.sh"
                ;;
        esac
        
        log_echo "✅ Система резервного копіювання налаштована."
        log_echo "Директорія бекапів: $BACKUP_DIR"
    else
        log_echo "✅ Автоматичне резервне копіювання пропущено."
    fi
}

# --- Функція налаштування Let's Encrypt ---
setup_letsencrypt() {
    log_echo "--- Налаштування Let's Encrypt SSL ---"
    
    if [ "$USE_CLOUDFLARE_TUNNEL" = "yes" ]; then
        log_echo "✅ Let's Encrypt пропущено (використовується Cloudflare Tunnel)"
        return
    fi
    
    while true; do
        read -p "Налаштувати Let's Encrypt SSL сертифікати? (yes/no) [yes]: " SETUP_SSL
        SETUP_SSL=${SETUP_SSL:-yes}
        case "$SETUP_SSL" in
            yes|no) break;;
            *) echo "Некоректний вибір. Будь ласка, введіть 'yes' або 'no'.";;
        esac
    done
    
    if [ "$SETUP_SSL" = "yes" ]; then
        # Встановлюємо Certbot
        log_echo "⏳ Встановлюю Certbot для Let's Encrypt..."
        apt update >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        apt install -y certbot >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        
        # Запитуємо email для Let's Encrypt
        while true; do
            read -p "Введіть email для Let's Encrypt сертифікатів: " LETSENCRYPT_EMAIL
            if [[ "$LETSENCRYPT_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                break
            else
                echo "Некоректний формат email. Спробуйте ще раз."
            fi
        done
        
        # Перевіряємо, чи порти 80 та 443 доступні
        log_echo "⏳ Перевіряю доступність портів 80 та 443..."
        if netstat -tuln | grep -q ":80 "; then
            log_echo "⚠️ Попередження: Порт 80 вже використовується."
        fi
        if netstat -tuln | grep -q ":443 "; then
            log_echo "⚠️ Попередження: Порт 443 вже використовується."
        fi
        
        # Отримуємо сертифікат
        log_echo "⏳ Отримую SSL сертифікат для домену $DOMAIN..."
        if certbot certonly --standalone --non-interactive --agree-tos --email "$LETSENCRYPT_EMAIL" -d "$DOMAIN" >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1; then
            log_echo "✅ SSL сертифікат успішно отримано."
            
            # Налаштовуємо автоматичне оновлення
            (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
            log_echo "✅ Налаштовано автоматичне оновлення SSL сертифікатів."
            
            # Створюємо Nginx конфігурацію
            setup_nginx_ssl
        else
            log_echo "❌ Помилка отримання SSL сертифікату. Перевірте DNS налаштування та доступність портів."
            log_echo "Продовжую встановлення без SSL..."
        fi
    else
        log_echo "✅ Let's Encrypt SSL пропущено."
    fi
}

# --- Функція налаштування Nginx з SSL ---
setup_nginx_ssl() {
    log_echo "⏳ Налаштовую Nginx з SSL..."
    
    # Встановлюємо Nginx
    apt install -y nginx >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
    
    # Створюємо конфігурацію Nginx
    cat > "/etc/nginx/sites-available/$DOMAIN" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Matrix Synapse
    location /_matrix {
        proxy_pass http://localhost:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
        client_max_body_size 50M;
    }

    # Element Web (якщо встановлено)
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
    }

    # Synapse Admin
    location /synapse-admin {
        proxy_pass http://localhost:8080;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
    }
}
EOF

    # Активуємо сайт
    ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/"
    rm -f /etc/nginx/sites-enabled/default
    
    # Перевіряємо конфігурацію та перезапускаємо Nginx
    if nginx -t >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1; then
        systemctl restart nginx
        systemctl enable nginx
        log_echo "✅ Nginx з SSL налаштовано та запущено."
    else
        log_echo "❌ Помилка в конфігурації Nginx. Перевірте логи."
    fi
}

# --- Функція налаштування моніторингу ---
setup_monitoring() {
    log_echo "--- Налаштування моніторингу та алертів ---"
    
    while true; do
        read -p "Налаштувати систему моніторингу (Prometheus + Grafana)? (yes/no) [yes]: " SETUP_MONITORING
        SETUP_MONITORING=${SETUP_MONITORING:-yes}
        case "$SETUP_MONITORING" in
            yes|no) break;;
            *) echo "Некоректний вибір. Будь ласка, введіть 'yes' або 'no'.";;
        esac
    done
    
    if [ "$SETUP_MONITORING" = "yes" ]; then
        # Створюємо директорії для моніторингу
        mkdir -p "$BASE_DIR/monitoring/prometheus"
        mkdir -p "$BASE_DIR/monitoring/grafana"
        
        # Конфігурація Prometheus
        cat > "$BASE_DIR/monitoring/prometheus/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'synapse'
    static_configs:
      - targets: ['synapse:9000']
    metrics_path: /_synapse/metrics

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
EOF

        # Правила алертів
        cat > "$BASE_DIR/monitoring/prometheus/alert_rules.yml" << EOF
groups:
  - name: matrix_alerts
    rules:
      - alert: SynapseDown
        expr: up{job="synapse"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Matrix Synapse is down"
          description: "Matrix Synapse has been down for more than 1 minute."

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is above 90% for more than 5 minutes."

      - alert: HighDiskUsage
        expr: (node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage"
          description: "Disk usage is above 80% for more than 5 minutes."
EOF

        # Створюємо базову конфігурацію Grafana
        mkdir -p "$BASE_DIR/monitoring/grafana/dashboards"
        mkdir -p "$BASE_DIR/monitoring/grafana/datasources"
        
        cat > "$BASE_DIR/monitoring/grafana/datasources/prometheus.yml" << EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

        # Налаштовуємо метрики для Synapse
        if [ -f "$BASE_DIR/synapse/config/homeserver.yaml" ]; then
            if ! grep -q "enable_metrics: true" "$BASE_DIR/synapse/config/homeserver.yaml"; then
                echo "" >> "$BASE_DIR/synapse/config/homeserver.yaml"
                echo "# Metrics for monitoring" >> "$BASE_DIR/synapse/config/homeserver.yaml"
                echo "enable_metrics: true" >> "$BASE_DIR/synapse/config/homeserver.yaml"
                echo "metrics_port: 9000" >> "$BASE_DIR/synapse/config/homeserver.yaml"
            fi
        fi
        
        log_echo "✅ Система моніторингу налаштована."
        log_echo "Prometheus буде доступний на порту 9090"
        log_echo "Grafana буде доступна на порту 3000 (admin/admin123)"
    else
        log_echo "✅ Моніторинг пропущено."
    fi
}

# --- Функція налаштування алертів ---
setup_alerts() {
    if [ "$SETUP_MONITORING" = "yes" ]; then
        log_echo "--- Налаштування системи алертів ---"
        
        while true; do
            read -p "Налаштувати email алерти? (yes/no) [no]: " SETUP_EMAIL_ALERTS
            SETUP_EMAIL_ALERTS=${SETUP_EMAIL_ALERTS:-no}
            case "$SETUP_EMAIL_ALERTS" in
                yes|no) break;;
                *) echo "Некоректний вибір. Будь ласка, введіть 'yes' або 'no'.";;
            esac
        done
        
        if [ "$SETUP_EMAIL_ALERTS" = "yes" ]; then
            read -p "Введіть email для отримання алертів: " ALERT_EMAIL
            read -p "Введіть SMTP сервер (наприклад, smtp.gmail.com:587): " SMTP_SERVER
            read -p "Введіть SMTP користувача: " SMTP_USER
            read -sp "Введіть SMTP пароль: " SMTP_PASSWORD
            echo
            
            # Створюємо конфігурацію Alertmanager
            mkdir -p "$BASE_DIR/monitoring/alertmanager"
            cat > "$BASE_DIR/monitoring/alertmanager/alertmanager.yml" << EOF
global:
  smtp_smarthost: '$SMTP_SERVER'
  smtp_from: '$SMTP_USER'
  smtp_auth_username: '$SMTP_USER'
  smtp_auth_password: '$SMTP_PASSWORD'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email-notifications'

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: '$ALERT_EMAIL'
        subject: 'Matrix Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
EOF
            
            log_echo "✅ Email алерти налаштовані."
        else
            log_echo "✅ Email алерти пропущені."
        fi
    fi
}

# --- Перевірка прав доступу ---
if [[ $EUID -ne 0 ]]; then
   # Ініціалізуємо файл логу тут, якщо він ще не створений, для запису першої помилки
   if [ ! -f "$FULL_LOG_PATH_FOR_SCRIPT" ] && [ -n "$FULL_LOG_PATH_FOR_SCRIPT" ]; then
       echo "=== Початок сесії встановлення Matrix $(date) ===" > "$FULL_LOG_PATH_FOR_SCRIPT"
   fi
   log_echo "Помилка: Цей скрипт потрібно запускати з правами root або через sudo."
   exit 1
fi

# Створюємо базову директорію /DATA якщо вона не існує
if [ ! -d "/DATA" ]; then
    mkdir -p /DATA
fi

# Ініціалізація файлу логу (якщо ще не створено)
if [ -n "$FULL_LOG_PATH_FOR_SCRIPT" ] && [ ! -f "$FULL_LOG_PATH_FOR_SCRIPT" ]; then
    echo "=== Початок сесії встановлення Matrix $(date) ===" > "$FULL_LOG_PATH_FOR_SCRIPT"
fi
log_echo "Файл логу сесії: $FULL_LOG_PATH_FOR_SCRIPT"
log_echo "Увага: Не всі інтерактивні запити будуть детально залоговані, але основні кроки, помилки та вивід команд - так."
echo # Порожній рядок для відокремлення

clear
log_echo "======================================================="
log_echo " Ласкаво просимо до покращеного майстра встановлення Matrix! "
log_echo " Версія 2.0 Enhanced з додатковими функціями"
log_echo "======================================================="
log_echo ""

# --- Крок 0: Валідація системних вимог ---
validate_system_requirements

# --- Крок 1: Інтерактивне збирання інформації ---
log_echo "--- Крок 1: Інтерактивне збирання інформації ---"
BASE_DIR="/DATA/matrix" # Базова директорія для всіх файлів Matrix
MAUTRIX_DOCKER_REGISTRY="dock.mau.dev/mautrix" # Повний шлях до Mautrix образів на dock.mau.dev
ELEMENT_WEB_VERSION="v1.11.104" # Версія Element Web для завантаження. Перевірте актуальну на https://github.com/element-hq/element-web/releases

# Перевіряємо, чи існує базова директорія
if [ -d "$BASE_DIR" ]; then
    log_echo "Виявлено існуючу директорію Matrix ($BASE_DIR)."
    while true; do
        read -p "Ви хочете оновити існуюче встановлення (лише Docker образи) чи створити нове? (update/new) [new]: " INSTALL_MODE
        INSTALL_MODE=${INSTALL_MODE:-new}
        case $INSTALL_MODE in
            update|new) break;;
            *) echo "Некоректний вибір. Будь ласка, введіть 'update' або 'new'.";;
        esac
    done
    if [ "$INSTALL_MODE" = "update" ]; then
        log_echo "✅ Ви обрали оновлення існуючого встановлення. Будуть оновлені Docker образи."
        log_echo "-------------------------------------------------"
        log_echo "Крок: Оновлення Docker образів"
        log_echo "-------------------------------------------------"
        log_echo "⚠️ Важливо: Цей режим оновить лише Docker образи. Якщо в нових версіях програмного забезпечення змінився формат конфігураційних файлів,"
        log_echo "вам може знадобитися оновити їх вручну. Завжди робіть резервні копії перед оновленням!"
        
        # Створюємо бекап перед оновленням
        if [ -f "/DATA/matrix-backups/backup-matrix.sh" ]; then
            log_echo "⏳ Створюю резервну копію перед оновленням..."
            /DATA/matrix-backups/backup-matrix.sh
        fi
        
        log_echo "⏳ Завантажую нові образи (docker compose pull)..."
        if docker compose -f "$BASE_DIR/docker-compose.yml" pull >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1; then
            log_echo "✅ Нові образи успішно завантажено."
        else
            log_echo "⚠️ Помилка під час docker compose pull. Спроба продовжити..."
        fi

        log_echo "⏳ Перезапускаю Docker стек з новими образами (docker compose up -d --remove-orphans)..."
        if docker compose -f "$BASE_DIR/docker-compose.yml" up -d --remove-orphans >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1; then
            log_echo "✅ Docker стек успішно перезапущено з новими образами."
        else
            log_echo "❌ Помилка під час перезапуску Docker стеку. Перевірте логи: $FULL_LOG_PATH_FOR_SCRIPT"
            exit 1
        fi
        log_echo "✅ Оновлення завершено."
        exit 0
    fi
    log_echo "Ви обрали створити нове встановлення, але директорія $BASE_DIR вже існує."
    read -p "Видалити існуючу директорію Matrix ($BASE_DIR) та створити нове встановлення? (yes/no) [no]: " DELETE_EXISTING
    DELETE_EXISTING=${DELETE_EXISTING:-no}
    if [ "$DELETE_EXISTING" = "yes" ]; then
        log_echo "⏳ Видаляю існуючу директорію Matrix: $BASE_DIR..."
        sudo rm -rf "$BASE_DIR"
        log_echo "✅ Існуючу директорію Matrix видалено."
    else
        log_echo "❌ Скасовано встановлення. Будь ласка, видаліть директорію вручну або виберіть 'update'."
        exit 1
    fi
fi

# Запитуємо домен
DEFAULT_DOMAIN="example.ua"
DOMAIN_VALID=false
while [ "$DOMAIN_VALID" = false ]; do
    read -p "Введіть ваш домен для Matrix [$DEFAULT_DOMAIN]: " DOMAIN
    DOMAIN=${DOMAIN:-$DEFAULT_DOMAIN}
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ && ! "$DOMAIN" =~ \.\. ]]; then
        if [[ ! "$DOMAIN" =~ ^[-.] && ! "$DOMAIN" =~ [-.]$ && ! "$DOMAIN" =~ \.- && ! "$DOMAIN" =~ -\. ]]; then
            DOMAIN_VALID=true
        else
            echo "Некоректний формат домену: не може починатися/закінчуватися дефісом або крапкою, або містити '.-' або '-.'."
        fi
    else
        echo "Некоректний формат домену. Будь ласка, введіть домен у форматі 'example.com' або 'sub.example.com'."
        echo "Домен повинен містити принаймні одну крапку, складатися з літер, цифр, дефісів та крапок."
    fi
done
log_echo "Обраний домен: $DOMAIN"

# Запитуємо пароль для бази даних
while true; do
    read -sp "Створіть надійний пароль для бази даних PostgreSQL: " POSTGRES_PASSWORD
    echo
    read -sp "Повторіть пароль: " POSTGRES_PASSWORD_CONFIRM
    echo
    [ "$POSTGRES_PASSWORD" = "$POSTGRES_PASSWORD_CONFIRM" ] && break
    echo "Паролі не співпадають. Спробуйте ще раз."
done
log_echo "Пароль для PostgreSQL встановлено."

# Запитуємо про публічну реєстрацію
while true; do
    read -p "Дозволити публічну реєстрацію нових користувачів? (yes/no) [no]: " ALLOW_PUBLIC_REGISTRATION
    ALLOW_PUBLIC_REGISTRATION=${ALLOW_PUBLIC_REGISTRATION:-no}
    case "$ALLOW_PUBLIC_REGISTRATION" in
        yes|no) break;;
        *) echo "Некоректний вибір. Будь ласка, введіть 'yes' або 'no'.";;
    esac
done
log_echo "Публічна реєстрація: $ALLOW_PUBLIC_REGISTRATION"

# Запитуємо про федерацію
while true; do
    read -p "Увімкнути федерацію (спілкування з іншими Matrix-серверами)? (yes/no) [no]: " ENABLE_FEDERATION
    ENABLE_FEDERATION=${ENABLE_FEDERATION:-no}
    case "$ENABLE_FEDERATION" in
        yes|no) break;;
        *) echo "Некоректний вибір. Будь ласка, введіть 'yes' або 'no'.";;
    esac
done
log_echo "Федерація: $ENABLE_FEDERATION"

# Запитуємо про встановлення Element Web
while true; do
    read -p "Встановити Element Web (офіційний клієнт Matrix)? (yes/no) [yes]: " INSTALL_ELEMENT
    INSTALL_ELEMENT=${INSTALL_ELEMENT:-yes}
    case "$INSTALL_ELEMENT" in
        yes|no) break;;
        *) echo "Некоректний вибір. Будь ласка, введіть 'yes' або 'no'.";;
    esac
done
log_echo "Встановлення Element Web: $INSTALL_ELEMENT"

echo
log_echo "--- Налаштування доступу до вашого Matrix-сервера ---"
echo "Ви можете використовувати Cloudflare Tunnel або Let's Encrypt через Nginx Proxy Manager (NPM)."
echo "Cloudflare Tunnel: Приховує IP вашого сервера, зручно, якщо ваш сервер за NAT."
echo "Let's Encrypt (NPM): Стандартний SSL-сертифікат для прямого доступу, вимагає відкритих портів 80/443."
echo "Одночасно використовувати їх не рекомендовано для одного домену."

USE_CLOUDFLARE_TUNNEL="no"
USE_NPM="no"
read -p "Використовувати Cloudflare Tunnel для доступу? (yes/no) [yes]: " USE_CLOUDFLARE_TUNNEL
USE_CLOUDFLARE_TUNNEL=${USE_CLOUDFLARE_TUNNEL:-yes}

CLOUDFLARE_TUNNEL_TOKEN=""
if [ "$USE_CLOUDFLARE_TUNNEL" = "yes" ]; then
    log_echo "Обрано Cloudflare Tunnel."
    echo "Для Cloudflare Tunnel вам потрібен токен тунелю."
    echo "Його можна отримати на панелі керування Cloudflare Zero Trust (Access -> Tunnels)."
    read -p "Введіть токен Cloudflare Tunnel: " CLOUDFLARE_TUNNEL_TOKEN
    if [ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
        log_echo "❌ Токен Cloudflare Tunnel не може бути порожнім, якщо ви обрали Cloudflare Tunnel. Скасовано."
        exit 1
    fi
    log_echo "Токен Cloudflare Tunnel надано."
    USE_NPM="no"
else
    log_echo "Cloudflare Tunnel не обрано."
    read -p "Використовувати Nginx Proxy Manager (NPM) з Let's Encrypt для доступу? (yes/no) [no]: " USE_NPM
    USE_NPM=${USE_NPM:-no}
    if [ "$USE_NPM" = "yes" ]; then
        log_echo "✅ Ви обрали Nginx Proxy Manager. Переконайтеся, що порти 80 та 443 доступні."
    else
        log_echo "Nginx Proxy Manager не обрано."
    fi
fi

echo
log_echo "--- Налаштування мостів (ботів) ---"
echo "Мости дозволяють інтегрувати Matrix з іншими месенджерами."

INSTALL_SIGNAL_BRIDGE="no"
INSTALL_WHATSAPP_BRIDGE="no"
INSTALL_TELEGRAM_BRIDGE="no"
INSTALL_DISCORD_BRIDGE="no"

read -p "Встановити Signal Bridge (для спілкування з користувачами Signal)? (yes/no) [no]: " INSTALL_SIGNAL_BRIDGE
INSTALL_SIGNAL_BRIDGE=${INSTALL_SIGNAL_BRIDGE:-no}
log_echo "Встановлення Signal Bridge: $INSTALL_SIGNAL_BRIDGE"

read -p "Встановити WhatsApp Bridge (для спілкування з користувачами WhatsApp)? (yes/no) [no]: " INSTALL_WHATSAPP_BRIDGE
INSTALL_WHATSAPP_BRIDGE=${INSTALL_WHATSAPP_BRIDGE:-no}
log_echo "Встановлення WhatsApp Bridge: $INSTALL_WHATSAPP_BRIDGE"

read -p "Встановити Telegram Bridge (для спілкування з користувачами Telegram)? (yes/no) [no]: " INSTALL_TELEGRAM_BRIDGE
INSTALL_TELEGRAM_BRIDGE=${INSTALL_TELEGRAM_BRIDGE:-no}
log_echo "Встановлення Telegram Bridge: $INSTALL_TELEGRAM_BRIDGE"

read -p "Встановити Discord Bridge (для спілкування з користувачами Discord)? (yes/no) [no]: " INSTALL_DISCORD_BRIDGE
INSTALL_DISCORD_BRIDGE=${INSTALL_DISCORD_BRIDGE:-no}
log_echo "Встановлення Discord Bridge: $INSTALL_DISCORD_BRIDGE"

# Запитуємо про встановлення Portainer
while true; do
    read -p "Встановити Portainer (веб-інтерфейс для керування Docker)? (yes/no) [yes]: " INSTALL_PORTAINER
    INSTALL_PORTAINER=${INSTALL_PORTAINER:-yes}
    case "$INSTALL_PORTAINER" in
        yes|no) break;;
        *) echo "Некоректний вибір. Будь ласка, введіть 'yes' або 'no'.";;
    esac
done
log_echo "Встановлення Portainer: $INSTALL_PORTAINER"

log_echo "-------------------------------------------------"
log_echo "Перевірка налаштувань:"
log_echo "Домен: $DOMAIN"
log_echo "Базова директорія: $BASE_DIR"
log_echo "Публічна реєстрація: $ALLOW_PUBLIC_REGISTRATION"
log_echo "Федерація: $ENABLE_FEDERATION"
log_echo "Встановлення Element Web: $INSTALL_ELEMENT"
log_echo "Використання Cloudflare Tunnel: $USE_CLOUDFLARE_TUNNEL"
log_echo "Використання Let's Encrypt (NPM): $USE_NPM"
log_echo "Встановлення Portainer: $INSTALL_PORTAINER"
log_echo "Встановлення Signal Bridge: $INSTALL_SIGNAL_BRIDGE"
log_echo "Встановлення WhatsApp Bridge: $INSTALL_WHATSAPP_BRIDGE"
log_echo "Встановлення Telegram Bridge: $INSTALL_TELEGRAM_BRIDGE"
log_echo "Встановлення Discord Bridge: $INSTALL_DISCORD_BRIDGE"
log_echo "-------------------------------------------------"
read -p "Натисніть Enter для продовження або Ctrl+C для скасування..."

# --- Функції ---
install_docker_dependencies() {
    log_echo "--- Функція: install_docker_dependencies ---"
    log_echo "⏳ Оновлюю списки пакетів..."
    apt update -y >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
    log_echo "✅ Списки пакетів оновлено."

    log_echo "⏳ Встановлюю базові пакети (curl, apt-transport-https, ca-certificates, gnupg)..."
    apt install -y curl apt-transport-https ca-certificates gnupg net-tools >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
    log_echo "✅ Базові пакети встановлено."

    log_echo "⏳ Встановлюю Docker Engine..."
    if ! systemctl is-active --quiet docker; then
        install -m 0755 -d /etc/apt/keyrings >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
            curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        fi
        if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        fi
        apt update -y >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        log_echo "✅ Docker Engine встановлено."
    else
        log_echo "✅ Docker вже встановлено."
    fi

    log_echo "⏳ Встановлюю Docker Compose..."
    # Перевіряємо спочатку плагін, потім окрему команду
    if docker compose version >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1; then
        log_echo "✅ Docker Compose (plugin) вже встановлено або встановлюється з Docker Engine."
    elif command -v docker-compose &> /dev/null; then
        log_echo "✅ Docker Compose (standalone) вже встановлено."
    else
        log_echo "❌ Docker Compose не знайдено. Docker Engine було встановлено з плагіном, але команда 'docker compose' недоступна, або Docker Engine не встановлено коректно."
        log_echo "Будь ласка, перевірте встановлення Docker та Docker Compose."
        # Спроба встановити docker-compose-plugin ще раз, якщо він не підтягнувся
        log_echo "Спроба доставити docker-compose-plugin..."
        apt install -y docker-compose-plugin >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        if docker compose version >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1; then
            log_echo "✅ Docker Compose (plugin) успішно доставлено."
        else
            log_echo "❌ Не вдалося встановити Docker Compose. Будь ласка, встановіть його вручну."
            exit 1
        fi
    fi
    log_echo "--- Кінець функції: install_docker_dependencies ---"
}

# --- Крок 2: Встановлення необхідних залежностей ---
log_echo "-------------------------------------------------"
log_echo "Крок: Встановлення необхідних залежностей"
log_echo "-------------------------------------------------"
install_docker_dependencies

if [ "$INSTALL_PORTAINER" = "yes" ]; then
    log_echo "⏳ Запускаю Portainer..."
    if ! docker ps -a --format '{{.Names}}' | grep -q "portainer"; then
        docker volume create portainer_data >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
            --restart always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data \
            portainer/portainer-ce:latest >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
        log_echo "✅ Portainer запущено. Доступно за адресою https://<IP_вашого_сервера>:9443"
    else
        log_echo "✅ Portainer вже запущено."
    fi
fi

# --- Налаштування резервного копіювання ---
setup_backup_system

# --- Налаштування Let's Encrypt ---
setup_letsencrypt

# --- Крок 3: Підготовка структури папок та генерація конфігурацій ---
log_echo "-------------------------------------------------"
log_echo "Крок: Підготовка структури папок та генерація конфігурацій"
log_echo "-------------------------------------------------"

log_echo "⏳ Створюю структуру папок у $BASE_DIR..."
mkdir -p "$BASE_DIR/synapse/config"
mkdir -p "$BASE_DIR/synapse/data"
mkdir -p "$BASE_DIR/element"
mkdir -p "$BASE_DIR/certs"

if [ "$INSTALL_SIGNAL_BRIDGE" = "yes" ]; then
    mkdir -p "$BASE_DIR/signal-bridge/config"
    mkdir -p "$BASE_DIR/signal-bridge/data"
fi
if [ "$INSTALL_WHATSAPP_BRIDGE" = "yes" ]; then
    mkdir -p "$BASE_DIR/whatsapp-bridge/config"
    mkdir -p "$BASE_DIR/whatsapp-bridge/data"
fi
if [ "$INSTALL_TELEGRAM_BRIDGE" = "yes" ]; then
    mkdir -p "$BASE_DIR/telegram-bridge/config"
    mkdir -p "$BASE_DIR/telegram-bridge/data"
fi
if [ "$INSTALL_DISCORD_BRIDGE" = "yes" ]; then
    mkdir -p "$BASE_DIR/discord-bridge/config"
    mkdir -p "$BASE_DIR/discord-bridge/data"
fi
log_echo "✅ Структуру папок створено."

log_echo "⏳ Генерую конфігураційний файл для Synapse (homeserver.yaml)..."
sudo docker run --rm \
    -v "$BASE_DIR/synapse/config:/data" \
    -e SYNAPSE_SERVER_NAME="$DOMAIN" \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1

log_echo "⏳ Встановлюю права доступу для homeserver.yaml та ключа підпису..."
if [ -f "$BASE_DIR/synapse/config/homeserver.yaml" ]; then
    sudo chown 991:991 "$BASE_DIR/synapse/config/homeserver.yaml"
    sudo chmod 600 "$BASE_DIR/synapse/config/homeserver.yaml"
else
    log_echo "⚠️ Попередження: Файл homeserver.yaml не знайдено для встановлення прав."
fi

if [ -f "$BASE_DIR/synapse/config/$DOMAIN.signing.key" ]; then
    sudo chown 991:991 "$BASE_DIR/synapse/config/$DOMAIN.signing.key"
    sudo chmod 600 "$BASE_DIR/synapse/config/$DOMAIN.signing.key"
else
    log_echo "⚠️ Попередження: Файл ключа підпису $DOMAIN.signing.key не знайдено у конфігураційній директорії для встановлення прав."
fi

SIGNING_KEY_IN_DATA_DIR="$BASE_DIR/synapse/data/$DOMAIN.signing.key"
SIGNING_KEY_IN_CONFIG_DIR="$BASE_DIR/synapse/config/$DOMAIN.signing.key"

if [ ! -f "$SIGNING_KEY_IN_DATA_DIR" ] && [ -f "$SIGNING_KEY_IN_CONFIG_DIR" ]; then
    log_echo "⏳ Копіюю ключ підпису до директорії даних Synapse..."
    cp "$SIGNING_KEY_IN_CONFIG_DIR" "$SIGNING_KEY_IN_DATA_DIR"
fi

log_echo "⏳ Встановлюю власника для директорії даних Synapse ($BASE_DIR/synapse/data)..."
sudo chown -R 991:991 "$BASE_DIR/synapse/data"
if [ -f "$SIGNING_KEY_IN_DATA_DIR" ]; then
    sudo chmod 600 "$SIGNING_KEY_IN_DATA_DIR"
fi
log_echo "✅ homeserver.yaml згенеровано та права доступу оновлено."

generate_bridge_config() {
    local bridge_name_human="$1"
    local bridge_dir_name="$2"
    local bridge_image_name="$3"
    local bridge_config_file_path="$BASE_DIR/$bridge_dir_name/config/config.yaml"
    local bridge_registration_file_path="$BASE_DIR/$bridge_dir_name/config/registration.yaml" # New variable

    log_echo "⏳ Генерую конфігураційний файл для $bridge_name_human ($bridge_config_file_path)..."
    mkdir -p "$BASE_DIR/$bridge_dir_name/config"

    # --- ВИПРАВЛЕННЯ: Додано змінні оточення MAUTRIX_CONFIG_PATH та MAUTRIX_REGISTRATION_PATH
    if sudo docker run --rm \
        -v "$BASE_DIR/$bridge_dir_name/config:/data" \
        -e MAUTRIX_CONFIG_PATH=/data/config.yaml \
        -e MAUTRIX_REGISTRATION_PATH=/data/registration.yaml \
        "$bridge_image_name" -g > "$bridge_config_file_path" 2>> "$FULL_LOG_PATH_FOR_SCRIPT"; then
        sudo chmod 600 "$bridge_config_file_path"
        log_echo "✅ Конфігураційний файл для $bridge_name_human згенеровано та встановлено права."
    else
        log_echo "❌ Помилка генерації конфігураційного файлу для $bridge_name_human. Див. деталі вище або в $FULL_LOG_PATH_FOR_SCRIPT."
    fi
}

if [ "$INSTALL_SIGNAL_BRIDGE" = "yes" ]; then
    generate_bridge_config "Signal Bridge" "signal-bridge" "$MAUTRIX_DOCKER_REGISTRY/signal:latest"
fi

if [ "$INSTALL_WHATSAPP_BRIDGE" = "yes" ]; then
    generate_bridge_config "WhatsApp Bridge" "whatsapp-bridge" "$MAUTRIX_DOCKER_REGISTRY/whatsapp:latest"
fi

if [ "$INSTALL_TELEGRAM_BRIDGE" = "yes" ]; then
    generate_bridge_config "Telegram Bridge" "telegram-bridge" "$MAUTRIX_DOCKER_REGISTRY/telegram:latest"
fi

if [ "$INSTALL_DISCORD_BRIDGE" = "yes" ]; then
    generate_bridge_config "Discord Bridge" "discord-bridge" "$MAUTRIX_DOCKER_REGISTRY/discord:latest"
fi

# --- Крок 4: Налаштування конфігураційних файлів ---
log_echo "-------------------------------------------------"
log_echo "Крок: Налаштування конфігураційних файлів"
log_echo "-------------------------------------------------"

HOMESERVER_CONFIG="$BASE_DIR/synapse/config/homeserver.yaml"

log_echo "⏳ Налаштовую базу даних PostgreSQL в homeserver.yaml..."
sed -i "s|#url: postgres://user:password@host:port/database|url: postgres://matrix_user:$POSTGRES_PASSWORD@postgres:5432/matrix_db|" "$HOMESERVER_CONFIG"
sed -i "/database:/a \ \   # Explicitly set the database type to pg (PostgreSQL)\n    name: pg" "$HOMESERVER_CONFIG"
log_echo "✅ Базу даних PostgreSQL налаштовано."

if [ "$ALLOW_PUBLIC_REGISTRATION" = "yes" ]; then
    log_echo "⏳ Вмикаю публічну реєстрацію в $HOMESERVER_CONFIG..."
    sed -i "s|enable_registration: false|enable_registration: true|" "$HOMESERVER_CONFIG"
    log_echo "✅ Публічну реєстрацію увімкнено."
else
    log_echo "✅ Публічна реєстрація вимкнена (за замовчуванням)."
fi

if [ "$ENABLE_FEDERATION" = "no" ]; then
    log_echo "⏳ Вимикаю федерацію в $HOMESERVER_CONFIG..."
    if ! grep -q "federation_enabled: false" "$HOMESERVER_CONFIG"; then
        sed -i "/#federation_client_minimum_tls_version:/a \ \ federation_enabled: false" "$HOMESERVER_CONFIG"
    fi
    log_echo "✅ Федерацію вимкнено."
else
    log_echo "✅ Федерація увімкнена (за замовчуванням)."
fi

log_echo "⏳ Додаю налаштування мостів до $HOMESERVER_CONFIG..."
if ! grep -q "app_service_config_files:" "$HOMESERVER_CONFIG"; then
cat <<EOF >> "$HOMESERVER_CONFIG"

# Mautrix Bridges Configuration
app_service_config_files:
EOF
fi

ensure_app_service_registered() {
    local service_file_path="$1"
    # Перевіряємо, чи шлях вже існує в файлі, ігноруючи пробіли на початку рядка
    if ! grep -q "^\s*-\s*$service_file_path" "$HOMESERVER_CONFIG"; then
        log_echo "Додаю $service_file_path до app_service_config_files"
        echo "  - $service_file_path" >> "$HOMESERVER_CONFIG"
    else
        log_echo "$service_file_path вже зареєстровано в app_service_config_files"
    fi
}

if [ "$INSTALL_SIGNAL_BRIDGE" = "yes" ]; then
    ensure_app_service_registered "/data/signal-registration.yaml"
fi
if [ "$INSTALL_WHATSAPP_BRIDGE" = "yes" ]; then
    ensure_app_service_registered "/data/whatsapp-registration.yaml"
fi
if [ "$INSTALL_TELEGRAM_BRIDGE" = "yes" ]; then
    ensure_app_service_registered "/data/telegram-registration.yaml"
fi
if [ "$INSTALL_DISCORD_BRIDGE" = "yes" ]; then
    ensure_app_service_registered "/data/discord-registration.yaml"
fi
log_echo "✅ Конфігурацію Synapse оновлено для мостів."

if [ "$INSTALL_ELEMENT" = "yes" ]; then
    log_echo "⏳ Завантажую та налаштовую Element Web..."
    ELEMENT_TAR="element-$ELEMENT_WEB_VERSION.tar.gz"
    ELEMENT_URL="https://github.com/element-hq/element-web/releases/download/$ELEMENT_WEB_VERSION/$ELEMENT_TAR"

    log_echo "Завантажую Element Web версії: $ELEMENT_WEB_VERSION з $ELEMENT_URL"
    curl -L "$ELEMENT_URL" -o "$BASE_DIR/$ELEMENT_TAR" >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
    log_echo "Розпаковую $ELEMENT_TAR до $BASE_DIR/element..."
    tar -xzf "$BASE_DIR/$ELEMENT_TAR" -C "$BASE_DIR/element" --strip-components=1
    rm "$BASE_DIR/$ELEMENT_TAR"

    log_echo "Створюю конфігураційний файл для Element: $BASE_DIR/element/config.json"
    cat <<EOF > "$BASE_DIR/element/config.json"
{
    "default_server_name": "$DOMAIN",
    "default_server_config": {
        "m.homeserver": {
            "base_url": "https://$DOMAIN",
            "server_name": "$DOMAIN"
        },
        "m.identity_server": {
            "base_url": "https://vector.im"
        }
    },
    "default_identity_server": "https://vector.im",
    "disable_custom_homeserver": false,
    "show_labs_settings": true,
    "brand": "Matrix ($DOMAIN)"
}
EOF
    log_echo "✅ Element Web завантажено та налаштовано."
else
    log_echo "✅ Встановлення Element Web пропущено."
fi

# --- Налаштування моніторингу ---
setup_monitoring

# --- Налаштування алертів ---
setup_alerts

# --- Крок 5: Створення файлу docker-compose.yml та .env ---
log_echo "-------------------------------------------------"
log_echo "Крок: Створення файлів docker-compose.yml та .env"
log_echo "-------------------------------------------------"

# --- ВИПРАВЛЕННЯ: Створюємо .env файл для Cloudflare Token
if [ "$USE_CLOUDFLARE_TUNNEL" = "yes" ]; then
    log_echo "⏳ Створюю файл .env з токеном Cloudflare Tunnel..."
    echo "CLOUDFLARE_TUNNEL_TOKEN=\"$CLOUDFLARE_TUNNEL_TOKEN\"" > "$BASE_DIR/.env"
    echo "POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\"" >> "$BASE_DIR/.env"
    log_echo "✅ Файл .env створено."
else
    echo "POSTGRES_PASSWORD=\"$POSTGRES_PASSWORD\"" > "$BASE_DIR/.env"
fi

# --- ВИПРАВЛЕННЯ: Порти для Synapse завжди експонуються для внутрішнього Docker-з'єднання, незалежно від тунелю
SYNAPSE_INTERNAL_PORTS="8008:8008\n      - 8448:8448" # Always expose ports for internal services

SYNAPSE_EXTERNAL_PORTS=""
if [ "$USE_CLOUDFLARE_TUNNEL" != "yes" ]; then
    # Only expose to host if not using Cloudflare Tunnel
    SYNAPSE_EXTERNAL_PORTS="- \"8008:8008\"\n      - \"8448:8448\""
fi

cat <<EOF > "$BASE_DIR/docker-compose.yml"
version: '3.8'

services:
  postgres:
    image: postgres:alpine
    restart: unless-stopped
    volumes:
      - ./synapse/data/postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: matrix_db
      POSTGRES_USER: matrix_user
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}

  synapse:
    image: matrixdotorg/synapse:latest
    restart: unless-stopped
    depends_on:
      - postgres
    volumes:
      - ./synapse/config:/data
      - ./synapse/data:/synapse/data
      - ./signal-bridge/config/registration.yaml:/data/signal-registration.yaml:ro
      - ./whatsapp-bridge/config/registration.yaml:/data/whatsapp-registration.yaml:ro
      - ./telegram-bridge/config/registration.yaml:/data/telegram-registration.yaml:ro
      - ./discord-bridge/config/registration.yaml:/data/discord-registration.yaml:ro
    environment:
      SYNAPSE_SERVER_NAME: $DOMAIN
      SYNAPSE_REPORT_STATS: "no"
      SYNAPSE_CONFIG_PATH: /data/homeserver.yaml
    ports:
      - "$SYNAPSE_INTERNAL_PORTS" # Internal ports for other containers
    expose:
      - "8008"
      - "8448"
      - "9000"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8008/_matrix/client/versions || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5

  synapse-admin:
    image: awesometechs/synapse-admin:latest
    restart: unless-stopped
    depends_on:
      - synapse
    environment:
      SYNAPSE_URL: http://synapse:8008
      SYNAPSE_SERVER_NAME: $DOMAIN
    ports:
      - "8080:80"

EOF

if [ "$INSTALL_ELEMENT" = "yes" ]; then
cat <<EOF >> "$BASE_DIR/docker-compose.yml"
  element:
    image: vectorim/element-web:latest
    restart: unless-stopped
    volumes:
      - ./element/config.json:/app/config.json:ro
    ports:
      - "80:80"
EOF
fi

if [ "$INSTALL_SIGNAL_BRIDGE" = "yes" ]; then
cat <<EOF >> "$BASE_DIR/docker-compose.yml"
  signal-bridge:
    image: ${MAUTRIX_DOCKER_REGISTRY}/signal:latest
    restart: unless-stopped
    depends_on:
      - synapse
    volumes:
      - ./signal-bridge/config:/data:z
      - ./signal-bridge/data:/data_bridge:z
    environment:
      - MAUTRIX_CONFIG_PATH=/data/config.yaml
      - MAUTRIX_REGISTRATION_PATH=/data/registration.yaml
    labels:
      - "mautrix_bridge=signal"
EOF
fi

if [ "$INSTALL_WHATSAPP_BRIDGE" = "yes" ]; then
cat <<EOF >> "$BASE_DIR/docker-compose.yml"
  whatsapp-bridge:
    image: ${MAUTRIX_DOCKER_REGISTRY}/whatsapp:latest
    restart: unless-stopped
    depends_on:
      - synapse
    volumes:
      - ./whatsapp-bridge/config:/data:z
      - ./whatsapp-bridge/data:/data_bridge:z
    environment:
      - MAUTRIX_CONFIG_PATH=/data/config.yaml
      - MAUTRIX_REGISTRATION_PATH=/data/registration.yaml
    labels:
      - "mautrix_bridge=whatsapp"
EOF
fi

if [ "$INSTALL_TELEGRAM_BRIDGE" = "yes" ]; then
cat <<EOF >> "$BASE_DIR/docker-compose.yml"
  telegram-bridge:
    image: ${MAUTRIX_DOCKER_REGISTRY}/telegram:latest
    restart: unless-stopped
    depends_on:
      - synapse
    volumes:
      - ./telegram-bridge/config:/data:z
      - ./telegram-bridge/data:/data_bridge:z
    environment:
      - MAUTRIX_CONFIG_PATH=/data/config.yaml
      - MAUTRIX_REGISTRATION_PATH=/data/registration.yaml
    labels:
      - "mautrix_bridge=telegram"
EOF
fi

if [ "$INSTALL_DISCORD_BRIDGE" = "yes" ]; then
cat <<EOF >> "$BASE_DIR/docker-compose.yml"
  discord-bridge:
    image: ${MAUTRIX_DOCKER_REGISTRY}/discord:latest
    restart: unless-stopped
    depends_on:
      - synapse
    volumes:
      - ./discord-bridge/config:/data:z
      - ./discord-bridge/data:/data_bridge:z
    environment:
      - MAUTRIX_CONFIG_PATH=/data/config.yaml
      - MAUTRIX_REGISTRATION_PATH=/data/registration.yaml
    labels:
      - "mautrix_bridge=discord"
EOF
fi

if [ "$USE_CLOUDFLARE_TUNNEL" = "yes" ]; then
cat <<EOF >> "$BASE_DIR/docker-compose.yml"
  cloudflared:
    image: cloudflare/cloudflared:latest
    restart: unless-stopped
    command: tunnel run --token \${CLOUDFLARE_TUNNEL_TOKEN}
    environment:
      - TUNNEL_TOKEN=\${CLOUDFLARE_TUNNEL_TOKEN}
EOF
fi

# Додаємо моніторинг до docker-compose.yml якщо потрібно
if [ "$SETUP_MONITORING" = "yes" ]; then
    cat >> "$BASE_DIR/docker-compose.yml" << 'EOF'

  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false

  node-exporter:
    image: prom/node-exporter:latest
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    restart: unless-stopped
    ports:
      - "9187:9187"
    environment:
      DATA_SOURCE_NAME: "postgresql://matrix_user:${POSTGRES_PASSWORD}@postgres:5432/matrix_db?sslmode=disable"
    depends_on:
      - postgres
EOF

    # Додаємо Alertmanager якщо налаштовано email алерти
    if [ "$SETUP_EMAIL_ALERTS" = "yes" ]; then
        cat >> "$BASE_DIR/docker-compose.yml" << 'EOF'

  alertmanager:
    image: prom/alertmanager:latest
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
EOF
    fi

    # Додаємо volumes
    cat >> "$BASE_DIR/docker-compose.yml" << 'EOF'

volumes:
  prometheus_data:
  grafana_data:
EOF
fi

log_echo "✅ Файл docker-compose.yml створено."

# --- Крок 6: Запуск Docker стеку та фінальне налаштування ---
log_echo "-------------------------------------------------"
log_echo "Крок: Запуск Docker стеку та фінальне налаштування"
log_echo "-------------------------------------------------"

log_echo "⏳ Завантажую Docker образи (docker compose pull)..."
cd "$BASE_DIR"
docker compose pull >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
log_echo "✅ Образи завантажено."
log_echo "⏳ Запускаю Docker стек (docker compose up -d)..."
docker compose up -d >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1
log_echo "✅ Docker стек запущено успішно."

log_echo "⏳ Чекаю, поки Matrix Synapse завантажиться (максимум 180 секунд)..."
for i in $(seq 1 18); do
    log_echo "Перевірка Synapse... (спроба $i, пройшло $(( (i-1)*10 )) секунд)..."
    if curl -sf http://localhost:8008/_matrix/client/versions > /dev/null; then
        log_echo "✅ Matrix Synapse запущено!"
        break
    fi
    if [ $i -eq 18 ]; then
        log_echo "❌ Помилка: Matrix Synapse не запустився після 180 секунд."
        log_echo "Будь ласка, вручну перевірте логи контейнера 'synapse' за допомогою 'docker logs matrix-synapse-1'."
        log_echo "Також перевірте лог Synapse всередині контейнера: docker exec matrix-synapse-1 cat /data/homeserver.log"
        log_echo "Можливо, вам знадобиться збільшити ліміти пам'яті для контейнера Synapse, якщо у вас недостатньо RAM."
        exit 1
    fi
    sleep 10
done

log_echo "⏳ Генерую файли реєстрації для мостів..."

generate_bridge_registration() {
    local bridge_name_human="$1"
    local bridge_service_name_in_compose="$2"
    local bridge_registration_file_path_in_synapse_container="$3"
    local bridge_appservice_id="$4"
    local bridge_internal_url="http://${bridge_service_name_in_compose}:8000"

    log_echo "Генерую реєстраційний файл для $bridge_name_human..."
    if sudo docker compose exec synapse generate_registration \
        --force \
        -u "$bridge_internal_url" \
        -c "$bridge_registration_file_path_in_synapse_container" \
        "$bridge_appservice_id" >> "$FULL_LOG_PATH_FOR_SCRIPT" 2>&1; then
        log_echo "✅ Реєстраційний файл для $bridge_name_human згенеровано."
    else
        log_echo "❌ Помилка генерації реєстраційного файлу для $bridge_name_human. Див. $FULL_LOG_PATH_FOR_SCRIPT."
    fi
}

# Перебуваємо в $BASE_DIR перед генерацією реєстрацій
cd "$BASE_DIR"

if [ "$INSTALL_SIGNAL_BRIDGE" = "yes" ]; then
    generate_bridge_registration "Signal Bridge" "signal-bridge" "/data/signal-registration.yaml" "io.mau.bridge.signal"
fi

if [ "$INSTALL_WHATSAPP_BRIDGE" = "yes" ]; then
    generate_bridge_registration "WhatsApp Bridge" "whatsapp-bridge" "/data/whatsapp-registration.yaml" "io.mau.bridge.whatsapp"
fi

if [ "$INSTALL_TELEGRAM_BRIDGE" = "yes" ]; then
    generate_bridge_registration "Telegram Bridge" "telegram-bridge" "/data/telegram-registration.yaml" "io.mau.bridge.telegram"
fi

if [ "$INSTALL_DISCORD_BRIDGE" = "yes" ]; then
    generate_bridge_registration "Discord Bridge" "discord-bridge" "/data/discord-registration.yaml" "io.mau.bridge.discord"
fi

# --- Створення скрипта для управління системою ---
log_echo "⏳ Створюю скрипт управління Matrix системою..."
cat > "$BASE_DIR/matrix-control.sh" << 'EOF'
#!/bin/bash
# Скрипт управління Matrix Synapse системою

MATRIX_DIR="$(dirname "$0")"
cd "$MATRIX_DIR"

case "$1" in
    start)
        echo "Запускаю Matrix систему..."
        docker compose up -d
        ;;
    stop)
        echo "Зупиняю Matrix систему..."
        docker compose down
        ;;
    restart)
        echo "Перезапускаю Matrix систему..."
        docker compose restart
        ;;
    status)
        echo "Статус Matrix системи:"
        docker compose ps
        ;;
    logs)
        if [ -n "$2" ]; then
            docker compose logs -f "$2"
        else
            docker compose logs -f
        fi
        ;;
    backup)
        if [ -f "/DATA/matrix-backups/backup-matrix.sh" ]; then
            /DATA/matrix-backups/backup-matrix.sh
        else
            echo "Скрипт резервного копіювання не знайдено."
        fi
        ;;
    update)
        echo "Оновлюю Docker образи..."
        docker compose pull
        docker compose up -d
        ;;
    *)
        echo "Використання: $0 {start|stop|restart|status|logs [service]|backup|update}"
        echo "Приклади:"
        echo "  $0 start          - Запустити всі сервіси"
        echo "  $0 stop           - Зупинити всі сервіси"
        echo "  $0 restart        - Перезапустити всі сервіси"
        echo "  $0 status         - Показати статус сервісів"
        echo "  $0 logs           - Показати логи всіх сервісів"
        echo "  $0 logs synapse   - Показати логи тільки Synapse"
        echo "  $0 backup         - Створити резервну копію"
        echo "  $0 update         - Оновити Docker образи"
        exit 1
        ;;
esac
EOF

chmod +x "$BASE_DIR/matrix-control.sh"
log_echo "✅ Скрипт управління створено: $BASE_DIR/matrix-control.sh"

log_echo "-------------------------------------------------"
log_echo "           ВСТАНОВЛЕННЯ ЗАВЕРШЕНО!             "
log_echo "-------------------------------------------------"
log_echo ""
log_echo "🎉 ВІТАЄМО! Ваш Matrix Synapse сервер успішно встановлено!"
log_echo ""
log_echo "📋 ІНФОРМАЦІЯ ПРО СИСТЕМУ:"
log_echo "Домен: $DOMAIN"
log_echo "Базова директорія: $BASE_DIR"
log_echo "Публічна реєстрація: $ALLOW_PUBLIC_REGISTRATION"
log_echo "Федерація: $ENABLE_FEDERATION"
log_echo "Element Web: $INSTALL_ELEMENT"
log_echo "Cloudflare Tunnel: $USE_CLOUDFLARE_TUNNEL"
log_echo "Моніторинг: $SETUP_MONITORING"
log_echo ""
log_echo "🔗 ДОСТУП ДО СЕРВІСІВ:"
if [ "$USE_CLOUDFLARE_TUNNEL" = "yes" ]; then
    log_echo "Matrix (Synapse): https://$DOMAIN"
    if [ "$INSTALL_ELEMENT" = "yes" ]; then
        log_echo "Element Web: https://$DOMAIN (налаштуйте в Cloudflare Tunnel)"
    fi
    log_echo "Synapse Admin: https://$DOMAIN/synapse-admin (налаштуйте в Cloudflare Tunnel)"
else
    log_echo "Matrix (Synapse): http://$(hostname -I | awk '{print $1}'):8008"
    if [ "$INSTALL_ELEMENT" = "yes" ]; then
        log_echo "Element Web: http://$(hostname -I | awk '{print $1}'):80"
    fi
    log_echo "Synapse Admin: http://$(hostname -I | awk '{print $1}'):8080"
fi

if [ "$INSTALL_PORTAINER" = "yes" ]; then
    log_echo "Portainer: https://$(hostname -I | awk '{print $1}'):9443"
fi

if [ "$SETUP_MONITORING" = "yes" ]; then
    log_echo "Prometheus: http://$(hostname -I | awk '{print $1}'):9090"
    log_echo "Grafana: http://$(hostname -I | awk '{print $1}'):3000 (admin/admin123)"
fi

log_echo ""
log_echo "🛠️ УПРАВЛІННЯ СИСТЕМОЮ:"
log_echo "Використовуйте скрипт: $BASE_DIR/matrix-control.sh"
log_echo "Приклади команд:"
log_echo "  $BASE_DIR/matrix-control.sh status    - Статус сервісів"
log_echo "  $BASE_DIR/matrix-control.sh restart   - Перезапуск"
log_echo "  $BASE_DIR/matrix-control.sh logs      - Перегляд логів"
log_echo "  $BASE_DIR/matrix-control.sh backup    - Резервне копіювання"
log_echo ""
log_echo "👤 СТВОРЕННЯ ПЕРШОГО КОРИСТУВАЧА:"
log_echo "cd $BASE_DIR"
log_echo "docker compose exec synapse register_new_matrix_user -c /data/homeserver.yaml -a -u <username> -p <password> http://localhost:8008"
log_echo ""
log_echo "🔧 НАЛАШТУВАННЯ МОСТІВ:"
if [ "$INSTALL_SIGNAL_BRIDGE" = "yes" ] || [ "$INSTALL_WHATSAPP_BRIDGE" = "yes" ] || [ "$INSTALL_TELEGRAM_BRIDGE" = "yes" ] || [ "$INSTALL_DISCORD_BRIDGE" = "yes" ]; then
    log_echo "Для налаштування мостів:"
    log_echo "1. Створіть користувача Matrix"
    log_echo "2. Увійдіть в Element Web або інший клієнт"
    log_echo "3. Знайдіть бота моста та почніть діалог"
    log_echo "4. Слідуйте інструкціям для підключення"
fi

log_echo ""
log_echo "💾 РЕЗЕРВНЕ КОПІЮВАННЯ:"
if [ "$SETUP_BACKUP" = "yes" ]; then
    log_echo "✅ Автоматичне резервне копіювання налаштовано"
    log_echo "Директорія бекапів: /DATA/matrix-backups"
    log_echo "Ручний запуск: /DATA/matrix-backups/backup-matrix.sh"
else
    log_echo "⚠️ Не забудьте налаштувати резервне копіювання!"
fi

log_echo ""
log_echo "🔒 БЕЗПЕКА:"
log_echo "- Регулярно оновлюйте систему: $BASE_DIR/matrix-control.sh update"
log_echo "- Робіть резервні копії перед оновленнями"
log_echo "- Моніторьте логи на предмет підозрілої активності"
log_echo "- Використовуйте сильні паролі для всіх облікових записів"

log_echo ""
log_echo "📚 КОРИСНІ ПОСИЛАННЯ:"
log_echo "- Документація Matrix: https://matrix.org/docs/"
log_echo "- Документація Synapse: https://matrix-org.github.io/synapse/"
log_echo "- Element Web: https://element.io/"
log_echo "- Mautrix Bridges: https://docs.mau.fi/"

log_echo ""
log_echo "📝 ФАЙЛИ ЛОГІВ:"
log_echo "Лог встановлення: $FULL_LOG_PATH_FOR_SCRIPT"
log_echo "Логи Docker: $BASE_DIR/matrix-control.sh logs"
if [ "$SETUP_BACKUP" = "yes" ]; then
    log_echo "Логи бекапів: /DATA/matrix-backups/backup.log"
fi

log_echo ""
log_echo "✅ Встановлення успішно завершено!"
log_echo "Дякуємо за використання покращеного скрипта встановлення Matrix Synapse!"
log_echo "=== Завершення сесії встановлення Matrix $(date) ==="
