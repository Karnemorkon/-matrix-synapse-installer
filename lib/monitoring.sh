#!/bin/bash
# ===================================================================================
# Monitoring Module - Prometheus, Grafana, and alerting
# ===================================================================================

# --- Functions ---
setup_monitoring_stack() {
    if [[ "${CONFIG[SETUP_MONITORING]}" != "true" ]]; then
        return 0
    fi
    
    log_info "Налаштування системи моніторингу"
    
    # Setup Prometheus
    setup_prometheus
    
    # Setup Grafana
    setup_grafana
    
    # Setup Alertmanager if email alerts are enabled
    if [[ "${CONFIG[SETUP_EMAIL_ALERTS]}" == "true" ]]; then
        setup_alertmanager
    fi
    
    log_success "Систему моніторингу налаштовано"
}

setup_prometheus() {
    local base_dir="${CONFIG[BASE_DIR]}"
    local prometheus_dir="${base_dir}/monitoring/prometheus"
    
    log_info "Налаштування Prometheus"
    
    # Create Prometheus configuration
    cat > "${prometheus_dir}/prometheus.yml" << EOF
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
    
    # Create alert rules
    create_alert_rules
    
    log_success "Prometheus налаштовано"
}

create_alert_rules() {
    local base_dir="${CONFIG[BASE_DIR]}"
    local prometheus_dir="${base_dir}/monitoring/prometheus"
    
    cat > "${prometheus_dir}/alert_rules.yml" << EOF
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

      - alert: PostgreSQLDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL is down"
          description: "PostgreSQL database has been down for more than 1 minute."

      - alert: HighDatabaseConnections
        expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High database connections"
          description: "Database connections are above 80% of maximum."
EOF
}

setup_grafana() {
    local base_dir="${CONFIG[BASE_DIR]}"
    local grafana_dir="${base_dir}/monitoring/grafana"
    
    log_info "Налаштування Grafana"
    
    # Create Grafana datasource configuration
    cat > "${grafana_dir}/datasources/prometheus.yml" << EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF
    
    # Create basic dashboard configuration
    create_grafana_dashboards
    
    log_success "Grafana налаштовано"
}

create_grafana_dashboards() {
    local base_dir="${CONFIG[BASE_DIR]}"
    local dashboards_dir="${base_dir}/monitoring/grafana/dashboards"
    
    # Create dashboard provisioning config
    mkdir -p "${base_dir}/monitoring/grafana/provisioning/dashboards"
    
    cat > "${base_dir}/monitoring/grafana/provisioning/dashboards/dashboards.yml" << EOF
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
    
    # Create a basic Matrix dashboard
    create_matrix_dashboard
}

create_matrix_dashboard() {
    local base_dir="${CONFIG[BASE_DIR]}"
    local dashboards_dir="${base_dir}/monitoring/grafana/dashboards"
    
    # This would be a complex JSON dashboard configuration
    # For brevity, we'll create a simple placeholder
    cat > "${dashboards_dir}/matrix-overview.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Matrix Synapse Overview",
    "tags": ["matrix", "synapse"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Synapse Status",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"synapse\"}",
            "legendFormat": "Synapse Up"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF
}

setup_alertmanager() {
    local base_dir="${CONFIG[BASE_DIR]}"
    local alertmanager_dir="${base_dir}/monitoring/alertmanager"
    
    log_info "Налаштування Alertmanager"
    
    cat > "${alertmanager_dir}/alertmanager.yml" << EOF
global:
  smtp_smarthost: '${CONFIG[SMTP_SERVER]}'
  smtp_from: '${CONFIG[SMTP_USER]}'
  smtp_auth_username: '${CONFIG[SMTP_USER]}'
  smtp_auth_password: '${CONFIG[SMTP_PASSWORD]}'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email-notifications'

receivers:
  - name: 'email-notifications'
    email_configs:
      - to: '${CONFIG[ALERT_EMAIL]}'
        subject: 'Matrix Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          {{ end }}
EOF
    
    log_success "Alertmanager налаштовано"
}

generate_monitoring_services() {
    if [[ "${CONFIG[SETUP_MONITORING]}" != "true" ]]; then
        return 0
    fi
    
    cat << EOF
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
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_INSTALL_PLUGINS=grafana-piechart-panel

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
      DATA_SOURCE_NAME: "postgresql://matrix_user:\${POSTGRES_PASSWORD}@postgres:5432/matrix_db?sslmode=disable"
    depends_on:
      - postgres
$(generate_alertmanager_service)
EOF
}

generate_alertmanager_service() {
    if [[ "${CONFIG[SETUP_EMAIL_ALERTS]}" != "true" ]]; then
        return 0
    fi
    
    cat << EOF

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
}
