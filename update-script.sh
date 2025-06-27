#!/bin/bash
# Скрипт оновлення Matrix Synapse системи

MATRIX_DIR="/DATA/matrix"
BACKUP_SCRIPT="/DATA/matrix-backups/backup-matrix.sh"

echo "🔄 Початок оновлення Matrix Synapse системи..."

# Перевірка прав root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Цей скрипт потрібно запускати з правами root або через sudo."
   exit 1
fi

# Створення бекапу перед оновленням
if [ -f "$BACKUP_SCRIPT" ]; then
    echo "💾 Створюю резервну копію перед оновленням..."
    $BACKUP_SCRIPT
    if [ $? -eq 0 ]; then
        echo "✅ Резервна копія створена успішно"
    else
        echo "❌ Помилка створення резервної копії"
        read -p "Продовжити без бекапу? (yes/no) [no]: " CONTINUE_WITHOUT_BACKUP
        if [ "$CONTINUE_WITHOUT_BACKUP" != "yes" ]; then
            echo "❌ Оновлення скасовано"
            exit 1
        fi
    fi
else
    echo "⚠️ Скрипт резервного копіювання не знайдено"
fi

cd "$MATRIX_DIR"

# Завантаження нових образів
echo "📥 Завантажую нові Docker образи..."
if docker compose pull; then
    echo "✅ Образи завантажено успішно"
else
    echo "❌ Помилка завантаження образів"
    exit 1
fi

# Перезапуск сервісів
echo "🔄 Перезапускаю сервіси з новими образами..."
if docker compose up -d --remove-orphans; then
    echo "✅ Сервіси перезапущено успішно"
else
    echo "❌ Помилка перезапуску сервісів"
    exit 1
fi

# Перевірка здоров'я після оновлення
echo "🏥 Перевіряю здоров'я системи після оновлення..."
sleep 30  # Чекаємо, поки сервіси запустяться

if curl -sf http://localhost:8008/_matrix/client/versions > /dev/null; then
    echo "✅ Matrix Synapse працює коректно"
else
    echo "❌ Matrix Synapse не відповідає"
    echo "Перевірте логи: docker compose logs synapse"
    exit 1
fi

# Очищення старих образів
echo "🧹 Очищую старі Docker образи..."
docker image prune -f

echo "🎉 Оновлення завершено успішно!"
echo "📊 Поточний статус системи:"
docker compose ps
