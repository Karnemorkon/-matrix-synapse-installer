# ===================================================================================
# Matrix Synapse Installer Dockerfile
# Версія: 4.0 З підтримкою веб інтерфейсу
# ===================================================================================

# Використовуємо Ubuntu 22.04 як базовий образ
FROM ubuntu:22.04

# Встановлюємо метадані
LABEL maintainer="Matrix Synapse Installer Team"
LABEL version="4.0"
LABEL description="Matrix Synapse Auto Installer with Web Dashboard"

# Встановлюємо змінні середовища
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV MATRIX_BASE_DIR=/DATA/matrix
ENV MATRIX_WEB_DASHBOARD_PORT=8081

# Оновлюємо систему та встановлюємо залежності
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libssl-dev \
    libffi-dev \
    docker.io \
    docker-compose \
    nginx \
    supervisor \
    cron \
    rsync \
    unzip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Створюємо користувача для безпеки
RUN useradd -m -s /bin/bash matrix && \
    usermod -aG docker matrix

# Створюємо директорії
RUN mkdir -p /opt/matrix-installer \
    /DATA/matrix \
    /var/log/matrix \
    /etc/matrix

# Копіюємо файли проекту
COPY . /opt/matrix-installer/

# Встановлюємо Python залежності для веб API
RUN pip3 install --no-cache-dir \
    flask \
    flask-cors \
    pyyaml \
    requests \
    psutil \
    docker \
    && pip3 install --no-cache-dir \
    pytest \
    pytest-cov \
    flake8 \
    black \
    isort

# Встановлюємо права на файли
RUN chmod +x /opt/matrix-installer/install.sh \
    /opt/matrix-installer/bin/matrix-control.sh \
    /opt/matrix-installer/lib/*.sh \
    && chown -R matrix:matrix /opt/matrix-installer \
    /DATA/matrix \
    /var/log/matrix

# Створюємо конфігурацію supervisor для веб API
RUN cat > /etc/supervisor/conf.d/matrix-api.conf << 'EOF'
[program:matrix-api]
command=python3 /opt/matrix-installer/web/api-server.py
directory=/opt/matrix-installer
user=matrix
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/matrix/api.log
environment=PYTHONUNBUFFERED=1
EOF

# Створюємо конфігурацію nginx для веб інтерфейсу
RUN cat > /etc/nginx/sites-available/matrix-dashboard << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        root /DATA/matrix/web/dashboard;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /static/ {
        alias /DATA/matrix/web/dashboard/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

# Активуємо конфігурацію nginx
RUN ln -sf /etc/nginx/sites-available/matrix-dashboard /etc/nginx/sites-enabled/ && \
    rm -f /etc/nginx/sites-enabled/default

# Створюємо скрипт ініціалізації
RUN cat > /opt/matrix-installer/init.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Ініціалізація Matrix Synapse Installer..."

# Запускаємо supervisor
supervisord -c /etc/supervisor/supervisord.conf

# Запускаємо nginx
nginx

# Перевіряємо чи потрібно встановлювати Matrix
if [[ ! -f /DATA/matrix/.installed ]]; then
    echo "📦 Встановлення Matrix Synapse..."
    
    # Встановлюємо Matrix з змінними середовища
    cd /opt/matrix-installer
    ./install.sh
    
    # Позначаємо як встановлено
    touch /DATA/matrix/.installed
    echo "✅ Matrix Synapse встановлено"
else
    echo "✅ Matrix Synapse вже встановлено"
fi

# Запускаємо Matrix сервіси
if [[ -f /DATA/matrix/docker-compose.yml ]]; then
    echo "🔧 Запуск Matrix сервісів..."
    cd /DATA/matrix
    docker-compose up -d
fi

echo "🎉 Ініціалізація завершена!"
echo "🌐 Веб інтерфейс: http://localhost:${MATRIX_WEB_DASHBOARD_PORT:-8081}"
echo "📊 API: http://localhost:${MATRIX_WEB_DASHBOARD_PORT:-8081}/api"

# Залишаємо контейнер запущеним
exec "$@"
EOF

RUN chmod +x /opt/matrix-installer/init.sh

# Встановлюємо робочу директорію
WORKDIR /opt/matrix-installer

# Відкриваємо порти
EXPOSE 80 8081

# Встановлюємо точку входу
ENTRYPOINT ["/opt/matrix-installer/init.sh"]
CMD ["tail", "-f", "/dev/null"]

# Метадані для збірки
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/your-repo/matrix-synapse-installer" 