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

# Експортуємо функції
export -f setup_security setup_firewall secure_file_permissions setup_letsencrypt_ssl setup_ssl_renewal setup_nginx_proxy create_security_documentation validate_ssl_certificate
