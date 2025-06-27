#!/bin/bash
# ===================================================================================
# Matrix Control Script - System management utility
# ===================================================================================

MATRIX_DIR="$(dirname "$(dirname "$0")")"
cd "$MATRIX_DIR"

show_usage() {
    cat << EOF
Matrix Synapse Control Script

Використання: $0 <команда> [параметри]

Команди:
  start                    Запустити всі сервіси
  stop                     Зупинити всі сервіси
  restart                  Перезапустити всі сервіси
  status                   Показати статус сервісів
  logs [service]           Показати логи (всіх сервісів або конкретного)
  update                   Оновити Docker образи
  health                   Перевірити здоров'я системи
  backup                   Створити резервну копію
  user create <username>   Створити нового користувача
  user list               Показати список користувачів

Приклади:
  $0 start
  $0 logs synapse
  $0 user create admin
EOF
}

case "$1" in
    start)
        echo "🚀 Запуск Matrix системи..."
        docker compose up -d
        ;;
    stop)
        echo "🛑 Зупинка Matrix системи..."
        docker compose down
        ;;
    restart)
        echo "🔄 Перезапуск Matrix системи..."
        docker compose restart
        ;;
    status)
        echo "📊 Статус Matrix системи:"
        docker compose ps
        ;;
    logs)
        if [ -n "$2" ]; then
            echo "📋 Логи сервісу $2:"
            docker compose logs -f "$2"
        else
            echo "📋 Логи всіх сервісів:"
            docker compose logs -f
        fi
        ;;
    update)
        echo "⬆️ Оновлення Docker образів..."
        docker compose pull
        echo "🔄 Перезапуск з новими образами..."
        docker compose up -d
        ;;
    health)
        echo "🏥 Перевірка здоров'я системи:"
        echo -n "Synapse API: "
        if curl -sf http://localhost:8008/_matrix/client/versions > /dev/null; then
            echo "✅ OK"
        else
            echo "❌ Недоступний"
        fi
        
        echo -n "База даних: "
        if docker compose exec -T postgres pg_isready -U matrix_user > /dev/null 2>&1; then
            echo "✅ OK"
        else
            echo "❌ Недоступна"
        fi
        ;;
    backup)
        if [ -f "/DATA/matrix-backups/backup-matrix.sh" ]; then
            echo "💾 Створення резервної копії..."
            /DATA/matrix-backups/backup-matrix.sh
        else
            echo "❌ Скрипт резервного копіювання не знайдено"
        fi
        ;;
    user)
        case "$2" in
            create)
                if [ -z "$3" ]; then
                    echo "❌ Вкажіть ім'я користувача"
                    echo "Використання: $0 user create <username>"
                    exit 1
                fi
                echo "👤 Створення користувача $3..."
                docker compose exec synapse register_new_matrix_user \
                    -c /data/homeserver.yaml \
                    -u "$3" \
                    -a \
                    http://localhost:8008
                ;;
            list)
                echo "👥 Список користувачів:"
                docker compose exec postgres psql -U matrix_user -d matrix_db \
                    -c "SELECT name, admin, deactivated FROM users ORDER BY name;"
                ;;
            *)
                echo "❌ Невідома команда користувача: $2"
                echo "Доступні команди: create, list"
                ;;
        esac
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
