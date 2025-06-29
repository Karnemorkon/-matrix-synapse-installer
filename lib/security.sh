#!/bin/bash
# ===================================================================================
# Модуль Безпеки - SSL, файрвол та конфігурації безпеки
# ===================================================================================

# --- Функції ---
setup_security() {
    log_step "Налаштування безпеки"
    
    # Налаштовуємо файрвол
    setup_firewall
    
    # Безпечні права доступу до файлів
    secure_file_permissions
    
    log_success "Безпеку налаштовано"
}

setup_letsencrypt_ssl() {
    if [[ "${USE_CLOUDFLARE_TUNNEL}" == "true" ]]; then
        log_info "Пропуск Let's Encrypt (використовується Cloudflare Tunnel)"
        return 0
    fi
    
    log_info "Налаштування Let's Encrypt SSL"
    
    # Встановлюємо Certbot
    log_command "apt update"
    log_command "apt install -y certbot nginx"
    
    # Отримуємо SSL сертифікат
    local domain="${DOMAIN}"
    local email="${LETSENCRYPT_EMAIL:-admin@${DOMAIN}}"
    
    log_info "Отримання SSL сертифікату для домену: ${domain}"
    
    if log_command "certbot certonly --standalone --non-interactive --agree-tos --email '${email}' -d '${domain}'"; then
        log_success "SSL сертифікат отримано"
        
        # Налаштовуємо автоматичне оновлення
        setup_ssl_renewal
        
        # Налаштовуємо Nginx reverse proxy
        setup_nginx_proxy
    else
        log_error "Помилка отримання SSL сертифікату"
        return 1
    fi
}

setup_ssl_renewal() {
    log_info "Налаштування автоматичного оновлення SSL"
    
    # Додаємо cron завдання для оновлення сертифікату
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
    
    log_success "Автоматичне оновлення SSL налаштовано"
}

setup_nginx_proxy() {
    local domain="${DOMAIN}"
    local base_dir="${BASE_DIR}"
    
    log_info "Налаштування Nginx reverse proxy"
    
    # Створюємо конфігурацію Nginx
    cat > "/etc/nginx/sites-available/${domain}" << EOF
server {
    listen 80;
    server_name ${domain};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${domain};

    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
    
    # Конфігурація SSL
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Заголовки безпеки
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # Matrix Synapse API
    location /_matrix {
        proxy_pass http://localhost:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
        client_max_body_size 50M;
        
        # Підтримка WebSocket
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Matrix Federation
    location /_matrix/federation {
        proxy_pass http://localhost:8448;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
    }
EOF

    # Додаємо локацію Element Web якщо встановлено (основний домен)
    if [[ "${INSTALL_ELEMENT}" == "true" ]]; then
        cat >> "/etc/nginx/sites-available/${domain}" << EOF

    # Element Web - основний домен
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
        
        # Додаткові заголовки для Element
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
    }
EOF
    fi

    cat >> "/etc/nginx/sites-available/${domain}" << EOF
}
EOF

    # Увімкнути сайт
    log_command "ln -sf '/etc/nginx/sites-available/${domain}' '/etc/nginx/sites-enabled/'"
    log_command "rm -f /etc/nginx/sites-enabled/default"
    
    # Тестуємо та перезавантажуємо Nginx
    if log_command "nginx -t"; then
        log_command "systemctl restart nginx"
        log_command "systemctl enable nginx"
        log_success "Nginx reverse proxy налаштовано"
    else
        log_error "Помилка в конфігурації Nginx"
        return 1
    fi
}

setup_firewall() {
    log_info "Налаштування файрволу..."
    
    # Встановлюємо UFW якщо не присутній
    if ! command -v ufw &> /dev/null; then
        apt install -y ufw &>> "${LOG_FILE}"
    fi
    
    # Налаштовуємо UFW з більш безпечними налаштуваннями за замовчуванням
    ufw --force reset &>> "${LOG_FILE}"
    ufw default deny incoming &>> "${LOG_FILE}"
    ufw default allow outgoing &>> "${LOG_FILE}"
    
    # Дозволяємо SSH (з обмеженням швидкості)
    ufw allow ssh &>> "${LOG_FILE}"
    ufw limit ssh &>> "${LOG_FILE}"
    
    # Дозволяємо порти Matrix з конкретними правилами
    ufw allow from any to any port 8008 proto tcp comment "Matrix Synapse HTTP" &>> "${LOG_FILE}"
    ufw allow from any to any port 8448 proto tcp comment "Matrix Synapse HTTPS" &>> "${LOG_FILE}"
    
    # Дозволяємо веб-порти якщо Element встановлено
    if [[ "${INSTALL_ELEMENT:-false}" == "true" ]]; then
        ufw allow from any to any port 80 proto tcp comment "HTTP" &>> "${LOG_FILE}"
        ufw allow from any to any port 443 proto tcp comment "HTTPS" &>> "${LOG_FILE}"
    fi
    
    # Synapse Admin - тільки локальний доступ
    ufw allow from 127.0.0.1 to any port 8080 proto tcp comment "Synapse Admin (localhost only)" &>> "${LOG_FILE}"
    
    # Дозволяємо порти моніторингу якщо увімкнено (обмежуємо до localhost)
    if [[ "${SETUP_MONITORING:-false}" == "true" ]]; then
        ufw allow from 127.0.0.1 to any port 3000 proto tcp comment "Grafana (localhost only)" &>> "${LOG_FILE}"
        ufw allow from 127.0.0.1 to any port 9090 proto tcp comment "Prometheus (localhost only)" &>> "${LOG_FILE}"
    fi
    
    # Увімкнути UFW
    ufw --force enable &>> "${LOG_FILE}"
    
    log_success "Файрвол налаштовано з підвищеною безпекою"
}

secure_file_permissions() {
    log_info "Налаштування прав доступу до файлів..."
    
    # Безпечна конфігурація Synapse
    if [[ -d "${BASE_DIR}/synapse" ]]; then
        chown -R 991:991 "${BASE_DIR}/synapse"
        chmod -R 750 "${BASE_DIR}/synapse"
        find "${BASE_DIR}/synapse" -type f -name "*.yaml" -exec chmod 640 {} \;
    fi
    
    # Безпечні файли бази даних
    if [[ -d "${BASE_DIR}/data/postgres" ]]; then
        chown -R 999:999 "${BASE_DIR}/data/postgres"
        chmod -R 750 "${BASE_DIR}/data/postgres"
    fi
    
    # Безпечні файли моніторингу
    if [[ -d "${BASE_DIR}/monitoring" ]]; then
        chown -R 472:472 "${BASE_DIR}/monitoring/grafana"
        chown -R 65534:65534 "${BASE_DIR}/monitoring/prometheus"
        chmod -R 750 "${BASE_DIR}/monitoring"
    fi
    
    log_success "Права доступу до файлів налаштовано"
}

validate_ssl_certificate() {
    local domain="$1"
    local cert_path="/etc/letsencrypt/live/${domain}/fullchain.pem"
    
    if [[ ! -f "${cert_path}" ]]; then
        log_error "SSL сертифікат не знайдено: ${cert_path}"
        return 1
    fi
    
    # Перевіряємо термін дії сертифікату
    local expiry_date=$(openssl x509 -enddate -noout -in "${cert_path}" | cut -d= -f2)
    local expiry_timestamp=$(date -d "${expiry_date}" +%s)
    local current_timestamp=$(date +%s)
    local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    if [[ ${days_until_expiry} -lt 30 ]]; then
        log_warning "SSL сертифікат закінчується через ${days_until_expiry} днів"
        return 1
    fi
    
    log_success "SSL сертифікат валідний (закінчується через ${days_until_expiry} днів)"
    return 0
}

create_security_documentation() {
    local base_dir="${BASE_DIR}"
    local docs_dir="${base_dir}/docs"
    
    cat > "${docs_dir}/SECURITY.md" << 'EOF'
# Безпека Matrix Synapse

## Рекомендації з безпеки

### 1. Регулярні оновлення
\`\`\`bash
# Оновлення системи
sudo apt update && sudo apt upgrade -y

# Оновлення Docker образів
./bin/matrix-control.sh update
EOF
}

# Перевірка SSL сертифікатів
check_ssl_certificates() {
    log_step "Перевірка SSL сертифікатів"
    
    local domain="${DOMAIN}"
    local cert_file="/etc/letsencrypt/live/${domain}/fullchain.pem"
    
    if [[ -f "$cert_file" ]]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [[ $days_until_expiry -lt 30 ]]; then
            log_warning "SSL сертифікат закінчується через $days_until_expiry днів"
            return 1
        else
            log_success "SSL сертифікат дійсний ще $days_until_expiry днів"
            return 0
        fi
    else
        log_error "SSL сертифікат не знайдено"
        return 1
    fi
}

# Налаштування додаткових заголовків безпеки
setup_security_headers() {
    log_info "Налаштування додаткових заголовків безпеки"
    
    local nginx_conf="/etc/nginx/conf.d/security-headers.conf"
    
    cat > "$nginx_conf" << 'EOF'
# Додаткові заголовки безпеки
add_header X-Content-Type-Options nosniff always;
add_header X-Frame-Options DENY always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none';" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# Обмеження розміру запитів
client_max_body_size 50M;
client_body_timeout 60s;
client_header_timeout 60s;

# Rate limiting
limit_req_zone $binary_remote_addr zone=matrix:10m rate=10r/s;
limit_req zone=matrix burst=20 nodelay;
EOF

    log_success "Заголовки безпеки налаштовано"
}

# Перевірка відкритих портів
check_open_ports() {
    log_step "Перевірка відкритих портів"
    
    local expected_ports=(22 80 443 8008 8448)
    local open_ports=$(ss -tuln | grep LISTEN | awk '{print $5}' | cut -d: -f2 | sort -u)
    
    for port in $open_ports; do
        if [[ ! " ${expected_ports[@]} " =~ " ${port} " ]]; then
            log_warning "Неочікуваний відкритий порт: $port"
        fi
    done
    
    log_success "Перевірка портів завершена"
}

# Налаштування fail2ban
setup_fail2ban() {
    log_step "Налаштування Fail2ban"
    
    # Встановлюємо fail2ban
    if ! command -v fail2ban-client &> /dev/null; then
        apt install -y fail2ban
    fi
    
    # Створюємо конфігурацію для Matrix
    cat > /etc/fail2ban/jail.d/matrix.conf << 'EOF'
[matrix-synapse]
enabled = true
port = 8008,8448
filter = matrix-synapse
logpath = /var/log/matrix/synapse.log
maxretry = 5
bantime = 3600
findtime = 600

[matrix-ssh]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

    # Створюємо фільтр для Matrix
    cat > /etc/fail2ban/filter.d/matrix-synapse.conf << 'EOF'
[Definition]
failregex = ^.*WARN.*-.*-.*Failed password attempt for.*<HOST>.*$
ignoreregex =
EOF

    # Перезапускаємо fail2ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log_success "Fail2ban налаштовано"
}

# Перевірка вразливостей
security_audit() {
    log_step "Аудит безпеки системи"
    
    local issues=0
    
    # Перевіряємо права доступу до конфігураційних файлів
    local config_files=(
        "${BASE_DIR}/synapse/config/homeserver.yaml"
        "${BASE_DIR}/docker-compose.yml"
        "${BASE_DIR}/.env"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms=$(stat -c %a "$file")
            if [[ $perms -gt 640 ]]; then
                log_warning "Небезпечні права доступу до $file: $perms"
                ((issues++))
            fi
        fi
    done
    
    # Перевіряємо чи UFW увімкнено
    if ! ufw status | grep -q "Status: active"; then
        log_warning "UFW не увімкнено"
        ((issues++))
    fi
    
    # Перевіряємо чи fail2ban запущений
    if ! systemctl is-active --quiet fail2ban; then
        log_warning "Fail2ban не запущений"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_success "Аудит безпеки пройшов успішно"
    else
        log_warning "Знайдено $issues проблем з безпекою"
    fi
    
    return $issues
}

# Експортуємо функції
export -f setup_security setup_firewall secure_file_permissions setup_letsencrypt_ssl setup_ssl_renewal setup_nginx_proxy create_security_documentation validate_ssl_certificate check_ssl_certificates setup_security_headers check_open_ports setup_fail2ban security_audit
