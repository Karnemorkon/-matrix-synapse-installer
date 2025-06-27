#!/bin/bash
# ===================================================================================
# Monitoring Module - Prometheus, Grafana, and Alertmanager setup
# ===================================================================================

# --- Functions ---
setup_monitoring_stack() {
    log_info "Налаштування стеку моніторингу..."
    
    # Create monitoring directories
    create_monitoring_directories
    
    # Generate Prometheus configuration
    generate_prometheus_config
    
    # Generate Grafana configuration
    generate_grafana_config
    
    # Generate Alertmanager configuration
    generate_alertmanager_config
    
    # Create dashboards
    create_grafana_dashboards
    
    log_success "Стек моніторингу налаштовано"
}

create_monitoring_directories() {
    local directories=(
        "$BASE_DIR/prometheus/data"
        "$BASE_DIR/prometheus/config"
        "$BASE_DIR/grafana/data"
        "$BASE_DIR/grafana/provisioning/dashboards"
        "$BASE_DIR/grafana/provisioning/datasources"
        "$BASE_DIR/alertmanager/data"
        "$BASE_DIR/alertmanager/config"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
    
    # Set proper permissions
    chown -R 472:472 "$BASE_DIR/grafana"
    chown -R 65534:65534 "$BASE_DIR/prometheus"
    chown -R 65534:65534 "$BASE_DIR/alertmanager"
}

generate_prometheus_config() {
    local config_file="$BASE_DIR/prometheus/config/prometheus.yml"
    
    cat > "$config_file" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "/etc/prometheus/rules/*.yml"

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

  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'nginx-exporter'
    static_configs:
      - targets: ['nginx-exporter:9113']
EOF

    # Create alert rules
    create_alert_rules
    
    log_success "Конфігурацію Prometheus створено"
}

create_alert_rules() {
    local rules_dir="$BASE_DIR/prometheus/config/rules"
    mkdir -p "$rules_dir"
    
    cat > "$rules_dir/matrix.yml" << 'EOF'
groups:
  - name: matrix.rules
    rules:
      - alert: SynapseDown
        expr: up{job="synapse"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Synapse is down"
          description: "Synapse has been down for more than 5 minutes."

      - alert: PostgreSQLDown
        expr: up{job="postgres-exporter"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL is down"
          description: "PostgreSQL has been down for more than 5 minutes."

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is above 90% for more than 10 minutes."

      - alert: HighDiskUsage
        expr: (node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_free_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage"
          description: "Disk usage is above 80% for more than 5 minutes."

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
          description: "CPU usage is above 80% for more than 10 minutes."
EOF
}

generate_grafana_config() {
    # Datasource configuration
    cat > "$BASE_DIR/grafana/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Dashboard provisioning
    cat > "$BASE_DIR/grafana/provisioning/dashboards/dashboard.yml" << EOF
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
      path: /var/lib/grafana/dashboards
EOF

    log_success "Конфігурацію Grafana створено"
}

generate_alertmanager_config() {
    local config_file="$BASE_DIR/alertmanager/config/alertmanager.yml"
    
    cat > "$config_file" << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@$DOMAIN'
  smtp_auth_username: ''
  smtp_auth_password: ''

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    email_configs:
      - to: '$ADMIN_EMAIL'
        subject: 'Matrix Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF

    log_success "Конфігурацію Alertmanager створено"
}

create_grafana_dashboards() {
    local dashboard_dir="$BASE_DIR/grafana/provisioning/dashboards"
    
    # Matrix Synapse Dashboard
    create_synapse_dashboard "$dashboard_dir/synapse.json"
    
    # System Dashboard
    create_system_dashboard "$dashboard_dir/system.json"
    
    # PostgreSQL Dashboard
    create_postgres_dashboard "$dashboard_dir/postgres.json"
    
    log_success "Дашборди Grafana створено"
}

create_synapse_dashboard() {
    local dashboard_file="$1"
    
    cat > "$dashboard_file" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Matrix Synapse",
    "tags": ["matrix", "synapse"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Active Users",
        "type": "stat",
        "targets": [
          {
            "expr": "synapse_admin_mau:current",
            "refId": "A"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {
                  "color": "green",
                  "value": null
                }
              ]
            }
          }
        },
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Federation Requests",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(synapse_federation_client_sent_transactions_total[5m])",
            "refId": "A",
            "legendFormat": "Sent"
          },
          {
            "expr": "rate(synapse_federation_server_received_transactions_total[5m])",
            "refId": "B",
            "legendFormat": "Received"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
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

create_system_dashboard() {
    local dashboard_file="$1"
    
    cat > "$dashboard_file" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "System Metrics",
    "tags": ["system", "node"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "refId": "A",
            "legendFormat": "CPU Usage %"
          }
        ],
        "yAxes": [
          {
            "max": 100,
            "min": 0,
            "unit": "percent"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
            "refId": "A",
            "legendFormat": "Memory Usage %"
          }
        ],
        "yAxes": [
          {
            "max": 100,
            "min": 0,
            "unit": "percent"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
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

create_postgres_dashboard() {
    local dashboard_file="$1"
    
    cat > "$dashboard_file" << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "PostgreSQL",
    "tags": ["postgresql", "database"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Database Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends",
            "refId": "A",
            "legendFormat": "{{datname}}"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Database Size",
        "type": "graph",
        "targets": [
          {
            "expr": "pg_database_size_bytes",
            "refId": "A",
            "legendFormat": "{{datname}}"
          }
        ],
        "yAxes": [
          {
            "unit": "bytes"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
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

add_monitoring_services() {
    local compose_file="$1"
    
    cat >> "$compose_file" << 'EOF'

  prometheus:
    image: prom/prometheus:latest
    container_name: matrix-prometheus
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    volumes:
      - ./prometheus/config:/etc/prometheus
      - ./prometheus/data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - matrix-net

  grafana:
    image: grafana/grafana:latest
    container_name: matrix-grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./grafana/data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    ports:
      - "3000:3000"
    networks:
      - matrix-net
    depends_on:
      - prometheus

  alertmanager:
    image: prom/alertmanager:latest
    container_name: matrix-alertmanager
    restart: unless-stopped
    volumes:
      - ./alertmanager/config:/etc/alertmanager
      - ./alertmanager/data:/alertmanager
    ports:
      - "9093:9093"
    networks:
      - matrix-net

  node-exporter:
    image: prom/node-exporter:latest
    container_name: matrix-node-exporter
    restart: unless-stopped
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    ports:
      - "9100:9100"
    networks:
      - matrix-net

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: matrix-postgres-exporter
    restart: unless-stopped
    environment:
      DATA_SOURCE_NAME: "postgresql://matrix_user:${POSTGRES_PASSWORD}@postgres:5432/matrix_db?sslmode=disable"
    ports:
      - "9187:9187"
    networks:
      - matrix-net
    depends_on:
      - postgres
EOF
}

# Export functions
export -f setup_monitoring_stack add_monitoring_services
