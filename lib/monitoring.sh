#!/bin/bash
# ===================================================================================
# Monitoring Module - Prometheus, Grafana, and Alertmanager setup
# ===================================================================================

# --- Functions ---
setup_monitoring_stack() {
    if [[ "${SETUP_MONITORING}" != "true" ]]; then
        return 0
    fi
    
    log_step "Налаштування системи моніторингу"
    
    # Create Prometheus configuration
    create_prometheus_config
    
    # Create Grafana datasource
    create_grafana_datasource
    
    # Create monitoring directories
    create_monitoring_directories
    
    # Generate Grafana configuration
    generate_grafana_config
    
    # Create dashboards
    create_grafana_dashboards
    
    log_success "Систему моніторингу налаштовано"
}

create_prometheus_config() {
    log_info "Створення конфігурації Prometheus..."
    
    cat > "${BASE_DIR}/monitoring/prometheus/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'synapse'
    static_configs:
      - targets: ['synapse:9000']
    metrics_path: /_synapse/metrics
EOF
    
    # Enable metrics in Synapse
    local homeserver_config="${BASE_DIR}/synapse/config/homeserver.yaml"
    if ! grep -q "enable_metrics: true" "${homeserver_config}"; then
        echo "" >> "${homeserver_config}"
        echo "# Metrics for monitoring" >> "${homeserver_config}"
        echo "enable_metrics: true" >> "${homeserver_config}"
        echo "metrics_port: 9000" >> "${homeserver_config}"
    fi
}

create_grafana_datasource() {
    log_info "Створення джерела даних Grafana..."
    
    cat > "${BASE_DIR}/monitoring/grafana/datasources/prometheus.yml" << EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
}

create_monitoring_directories() {
    local directories=(
        "${BASE_DIR}/monitoring/prometheus/data"
        "${BASE_DIR}/monitoring/prometheus/config"
        "${BASE_DIR}/monitoring/grafana/data"
        "${BASE_DIR}/monitoring/grafana/dashboards"
        "${BASE_DIR}/monitoring/grafana/datasources"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
    
    # Set proper permissions
    chown -R 472:472 "${BASE_DIR}/monitoring/grafana"
    chown -R 65534:65534 "${BASE_DIR}/monitoring/prometheus"
}

generate_grafana_config() {
    # Dashboard provisioning
    cat > "${BASE_DIR}/monitoring/grafana/provisioning/dashboards/dashboard.yml" << EOF
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

create_grafana_dashboards() {
    local dashboard_dir="${BASE_DIR}/monitoring/grafana/dashboards"
    
    # Matrix Synapse Dashboard
    create_synapse_dashboard "${dashboard_dir}/synapse.json"
    
    # System Dashboard
    create_system_dashboard "${dashboard_dir}/system.json"
    
    # PostgreSQL Dashboard
    create_postgres_dashboard "${dashboard_dir}/postgres.json"
    
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
      - ./monitoring/prometheus/config:/etc/prometheus
      - ./monitoring/prometheus/data:/prometheus
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
      - ./monitoring/grafana/data:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning
    ports:
      - "3000:3000"
    networks:
      - matrix-net
    depends_on:
      - prometheus

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
export -f setup_monitoring_stack add_monitoring_services create_prometheus_config create_grafana_datasource
