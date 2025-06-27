#!/bin/bash
# ===================================================================================
# Security Module - SSL, firewall, and security configurations
# ===================================================================================

# --- Functions ---
setup_security() {
    log_info "Налаштування безпеки"
    
    # Setup SSL if needed
    if [[ "${CONFIG[USE_LETSENCRYPT]}" == "true" ]]; then
        setup_letsencrypt_ssl
    fi
    
    # Setup basic firewall
    setup_firewall
    
    # Set secure file permissions
    set_secure_permissions
    
    log_success "Безпеку налаштовано"
}

setup_letsencrypt_ssl() {
    if [[ "${CONFIG[USE_CLOUDFLARE_TUNNEL]}" == "true" ]]; then
        log_info "Пропуск Let's Encrypt (використовується Cloudflare Tunnel)"
        return 0
    fi
    
    log_info "Налаштування Let's Encrypt SSL"
    
    # Install Certbot
    log_command "apt update"
    log_command "apt install -y certbot nginx"
    
    # Get SSL certificate
    local domain="${CONFIG[DOMAIN]}"
    local email="${CONFIG[LETSENCRYPT_EMAIL]}"
    
    log_info "Отримання SSL сертифікату для домену: ${domain}"
    
    if log_command "certbot certonly --standalone --non-interactive --agree-tos --email '${email}' -d '${domain}'"; then
        log_success "SSL сертифікат отримано"
        
        # Setup automatic renewal
        setup_ssl_renewal
        
        # Setup Nginx reverse proxy
        setup_nginx_proxy
    else
        log_error "Помилка отримання SSL сертифікату"
        return 1
    fi
}

setup_ssl_renewal() {
    log_info "Налаштування автоматичного оновлення SSL"
    
    # Add cron job for certificate renewal
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
    
    log_success "Автоматичне оновлення SSL налаштовано"
}

setup_nginx_proxy() {
    local domain="${CONFIG[DOMAIN]}"
    local base_dir="${CONFIG[BASE_DIR]}"
    
    log_info "Налаштування Nginx reverse proxy"
    
    # Create Nginx configuration
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
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options DENY;
    add_header X-XSS-Protection "1; mode=block";

    # Matrix Synapse
    location /_matrix {
        proxy_pass http://localhost:8008;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
        client_max_body_size 50M;
        
        # WebSocket support
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

    # Add Element Web location if installed
    if [[ "${CONFIG[INSTALL_ELEMENT]}" == "true" ]]; then
        cat >> "/etc/nginx/sites-available/${domain}" << EOF

    # Element Web
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
    }
EOF
    fi

    # Add Synapse Admin location
    cat >> "/etc/nginx/sites-available/${domain}" << EOF

    # Synapse Admin
    location /admin {
        proxy_pass http://localhost:8080;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Host \$host;
    }
}
EOF

    # Enable site
    log_command "ln -sf '/etc/nginx/sites-available/${domain}' '/etc/nginx/sites-enabled/'"
    log_command "rm -f /etc/nginx/sites-enabled/default"
    
    # Test and reload Nginx
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
    log_info "Налаштування базового файрволу"
    
    # Install UFW if not present
    if ! command -v ufw &> /dev/null; then
        log_command "apt install -y ufw"
    fi
    
    # Reset UFW to defaults
    log_command "ufw --force reset"
    
    # Set default policies
    log_command "ufw default deny incoming"
    log_command "ufw default allow outgoing"
    
    # Allow SSH
    log_command "ufw allow ssh"
    
    # Allow HTTP and HTTPS if not using Cloudflare Tunnel
    if [[ "${CONFIG[USE_CLOUDFLARE_TUNNEL]}" != "true" ]]; then
        log_command "ufw allow 80/tcp"
        log_command "ufw allow 443/tcp"
        log_command "ufw allow 8008/tcp"
        log_command "ufw allow 8448/tcp"
    fi
    
    # Allow monitoring ports if monitoring is enabled
    if [[ "${CONFIG[SETUP_MONITORING]}" == "true" ]]; then
        log_command "ufw allow 3000/tcp"  # Grafana
        log_command "ufw allow 9090/tcp"  # Prometheus
    fi
    
    # Allow Portainer if installed
    if [[ "${CONFIG[INSTALL_PORTAINER]}" == "true" ]]; then
        log_command "ufw allow 9443/tcp"
    fi
    
    # Enable UFW
    log_command "ufw --force enable"
    
    log_success "Файрвол налаштовано"
}

set_secure_permissions() {
    local base_dir="${CONFIG[BASE_DIR]}"
    
    log_info "Встановлення безпечних прав доступу"
    
    # Set ownership for Matrix directories
    log_command "chown -R 991:991 '${base_dir}/synapse'"
    
    # Set secure permissions for configuration files
    log_command "chmod 600 '${base_dir}/.env'"
    log_command "find '${base_dir}' -name '*.yaml' -type f -exec chmod 600 {} +"
    log_command "find '${base_dir}' -name '*.yml' -type f -exec chmod 600 {} +"
    
    # Set permissions for scripts
    log_command "chmod +x '${base_dir}/bin/'*.sh"
    
    log_success "Права доступу встановлено"
}

create_security_documentation() {
    local base_dir="${CONFIG[BASE_DIR]}"
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
