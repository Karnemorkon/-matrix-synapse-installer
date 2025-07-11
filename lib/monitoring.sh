#!/bin/bash
# ===================================================================================
# Модуль Моніторингу - Налаштування Prometheus, Grafana та Alertmanager
# ===================================================================================

# --- Функції ---
setup_monitoring_stack() {
    if [[ "${SETUP_MONITORING}" != "true" ]]; then
        return 0
    fi
    
    log_step "Налаштування системи моніторингу"
    
    # Спочатку створюємо директорії моніторингу
    create_monitoring_directories
    
    # Створюємо конфігурацію Prometheus
    create_prometheus_config
    
    # Створюємо джерело даних Grafana
    create_grafana_datasource
    
    # Генеруємо конфігурацію Grafana
    generate_grafana_config
    
    # Створюємо дашборди
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
    
    # Увімкнути метрики в Synapse
    local homeserver_config="${BASE_DIR}/synapse/config/homeserver.yaml"
    if ! grep -q "enable_metrics: true" "${homeserver_config}"; then
        echo "" >> "${homeserver_config}"
        echo "# Метрики для моніторингу" >> "${homeserver_config}"
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
        "${BASE_DIR}/monitoring/grafana/provisioning"
        "${BASE_DIR}/monitoring/grafana/provisioning/dashboards"
        "${BASE_DIR}/monitoring/grafana/provisioning/datasources"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
    
    # Встановлюємо правильні права
    chown -R 472:472 "${BASE_DIR}/monitoring/grafana"
    chown -R 65534:65534 "${BASE_DIR}/monitoring/prometheus"
}

generate_grafana_config() {
    # Провайдинг дашбордів
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
    
    # Дашборд Matrix Synapse
    create_synapse_dashboard "${dashboard_dir}/synapse.json"
    
    # Системний дашборд
    create_system_dashboard "${dashboard_dir}/system.json"
    
    # Дашборд PostgreSQL
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
    "title": "System Resources",
    "tags": ["system", "resources"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "refId": "A",
            "legendFormat": "CPU %"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        },
        "yAxes": [
          {
            "label": "CPU %",
            "min": 0,
            "max": 100
          }
        ]
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
            "refId": "A",
            "legendFormat": "Memory %"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        },
        "yAxes": [
          {
            "label": "Memory %",
            "min": 0,
            "max": 100
          }
        ]
      },
      {
        "id": 3,
        "title": "Disk Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "(node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100",
            "refId": "A",
            "legendFormat": "Disk %"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 8
        },
        "yAxes": [
          {
            "label": "Disk %",
            "min": 0,
            "max": 100
          }
        ]
      },
      {
        "id": 4,
        "title": "Network Traffic",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(node_network_receive_bytes_total[5m])",
            "refId": "A",
            "legendFormat": "Receive"
          },
          {
            "expr": "rate(node_network_transmit_bytes_total[5m])",
            "refId": "B",
            "legendFormat": "Transmit"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 8
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

# Створення алертів для Grafana
create_grafana_alerts() {
    log_info "Створення алертів Grafana"
    
    local alerts_dir="${BASE_DIR}/monitoring/grafana/alerts"
    mkdir -p "$alerts_dir"
    
    # Алерт для високого навантаження CPU
    cat > "$alerts_dir/cpu_alert.json" << 'EOF'
{
  "alert": {
    "name": "High CPU Usage",
    "message": "CPU usage is above 80% for more than 5 minutes",
    "executionErrorState": "keep_state",
    "for": "5m",
    "frequency": "1m",
    "handler": 1,
    "severity": "warning"
  },
  "conditions": [
    {
      "type": "query",
      "query": {
        "params": [
          "A",
          "5m",
          "now"
        ]
      },
      "reducer": {
        "type": "avg",
        "params": []
      },
      "evaluator": {
        "type": "gt",
        "params": [
          80
        ]
      }
    }
  ]
}
EOF

    # Алерт для високого використання пам'яті
    cat > "$alerts_dir/memory_alert.json" << 'EOF'
{
  "alert": {
    "name": "High Memory Usage",
    "message": "Memory usage is above 85% for more than 5 minutes",
    "executionErrorState": "keep_state",
    "for": "5m",
    "frequency": "1m",
    "handler": 1,
    "severity": "warning"
  },
  "conditions": [
    {
      "type": "query",
      "query": {
        "params": [
          "A",
          "5m",
          "now"
        ]
      },
      "reducer": {
        "type": "avg",
        "params": []
      },
      "evaluator": {
        "type": "gt",
        "params": [
          85
        ]
      }
    }
  ]
}
EOF

    log_success "Алерти Grafana створено"
}

# Налаштування експортера системних метрик
setup_node_exporter() {
    log_step "Налаштування Node Exporter"
    
    # Додаємо Node Exporter до docker-compose.yml
    local compose_file="${BASE_DIR}/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        # Додаємо Node Exporter після секції prometheus
        sed -i '/prometheus:/a\
  node-exporter:\
    image: prom/node-exporter:latest\
    restart: unless-stopped\
    ports:\
      - "9100:9100"\
    volumes:\
      - /proc:/host/proc:ro\
      - /sys:/host/sys:ro\
      - /:/rootfs:ro\
    command:\
      - "--path.procfs=/host/proc"\
      - "--path.sysfs=/host/sys"\
      - "--path.rootfs=/rootfs"\
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"' "$compose_file"
        
        # Оновлюємо конфігурацію Prometheus
        local prometheus_config="${BASE_DIR}/monitoring/prometheus/prometheus.yml"
        if [[ -f "$prometheus_config" ]]; then
            # Додаємо job для node-exporter
            sed -i '/synapse:/a\
  - job_name: "node-exporter"\
    static_configs:\
      - targets: ["node-exporter:9100"]' "$prometheus_config"
        fi
        
        log_success "Node Exporter налаштовано"
    else
        log_error "Docker Compose файл не знайдено"
        return 1
    fi
}

# Налаштування логування в Loki
setup_loki_logging() {
    log_step "Налаштування Loki для логування"
    
    local compose_file="${BASE_DIR}/docker-compose.yml"
    
    if [[ -f "$compose_file" ]]; then
        # Додаємо Loki після секції grafana
        sed -i '/grafana:/a\
  loki:\
    image: grafana/loki:latest\
    restart: unless-stopped\
    ports:\
      - "3100:3100"\
    command:\
      - "-config.file=/etc/loki/local-config.yaml"\
    volumes:\
      - ./monitoring/loki:/etc/loki\
      - loki_data:/loki' "$compose_file"
        
        # Створюємо конфігурацію Loki
        mkdir -p "${BASE_DIR}/monitoring/loki"
        cat > "${BASE_DIR}/monitoring/loki/local-config.yaml" << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    cache_ttl: 24h
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

compactor:
  working_directory: /loki/compactor
  shared_store: filesystem

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
EOF
        
        # Додаємо Loki як джерело даних в Grafana
        cat > "${BASE_DIR}/monitoring/grafana/datasources/loki.yml" << 'EOF'
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: false
EOF
        
        log_success "Loki налаштовано для логування"
    else
        log_error "Docker Compose файл не знайдено"
        return 1
    fi
}

# Експортуємо функції
export -f setup_monitoring_stack add_monitoring_services create_prometheus_config create_grafana_datasource
export -f create_grafana_alerts setup_node_exporter create_system_dashboard setup_loki_logging
