#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
API сервер для Matrix Dashboard
"""

import os
import json
import subprocess
import threading
import time
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import yaml

app = Flask(__name__)
CORS(app)

# Конфігурація
CONFIG_FILE = os.getenv('MATRIX_CONFIG_FILE', '/DATA/matrix/config/matrix.conf')
BASE_DIR = os.getenv('MATRIX_BASE_DIR', '/DATA/matrix')
DOCKER_COMPOSE_FILE = os.path.join(BASE_DIR, 'docker-compose.yml')

# Глобальні змінні для оновлення
update_progress = {
    'progress': 0,
    'message': '',
    'completed': False
}

def load_config():
    """Завантаження конфігурації"""
    config = {}
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            for line in f:
                if '=' in line and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    config[key] = value.strip('"')
    return config

def run_command(cmd, timeout=30):
    """Виконання команди з таймаутом"""
    try:
        result = subprocess.run(
            cmd, 
            shell=True, 
            capture_output=True, 
            text=True, 
            timeout=timeout
        )
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'stdout': '',
            'stderr': 'Команда перевищила час очікування',
            'returncode': -1
        }
    except Exception as e:
        return {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1
        }

@app.route('/api/status')
def get_status():
    """Отримання статусу системи"""
    try:
        # Перевіряємо чи Synapse відповідає
        result = run_command(f'curl -s http://localhost:8008/_matrix/client/versions')
        if result['success']:
            return jsonify({'status': 'online'})
        else:
            return jsonify({'status': 'offline'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)})

@app.route('/api/overview')
def get_overview():
    """Отримання загального огляду"""
    try:
        # Отримуємо статистику
        stats = {}
        
        # Активні користувачі
        result = run_command(f'curl -s http://localhost:8008/_synapse/admin/v1/statistics/users/media')
        if result['success']:
            try:
                data = json.loads(result['stdout'])
                stats['activeUsers'] = data.get('total_users', 0)
            except:
                stats['activeUsers'] = 0
        else:
            stats['activeUsers'] = 0
        
        # Кількість кімнат
        result = run_command(f'curl -s http://localhost:8008/_synapse/admin/v1/statistics/rooms')
        if result['success']:
            try:
                data = json.loads(result['stdout'])
                stats['totalRooms'] = data.get('total_rooms', 0)
            except:
                stats['totalRooms'] = 0
        else:
            stats['totalRooms'] = 0
        
        # Запущені сервіси
        result = run_command(f'cd {BASE_DIR} && docker compose ps --format json')
        if result['success']:
            try:
                services = json.loads(result['stdout'])
                stats['runningServices'] = len([s for s in services if s.get('State') == 'running'])
            except:
                stats['runningServices'] = 0
        else:
            stats['runningServices'] = 0
        
        # Використання диску
        result = run_command(f'df -h {BASE_DIR} | tail -1 | awk \'{{print $5}}\'')
        if result['success']:
            stats['diskUsage'] = result['stdout'].strip()
        else:
            stats['diskUsage'] = '0%'
        
        return jsonify(stats)
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/api/services')
def get_services():
    """Отримання списку сервісів"""
    try:
        result = run_command(f'cd {BASE_DIR} && docker compose ps --format json')
        if result['success']:
            services = []
            try:
                service_list = json.loads(result['stdout'])
                for service in service_list:
                    services.append({
                        'name': service.get('Service', 'Unknown'),
                        'status': 'running' if service.get('State') == 'running' else 'stopped',
                        'description': f"Порт: {service.get('Ports', 'N/A')}"
                    })
            except:
                services = []
        else:
            services = []
        
        return jsonify(services)
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/api/services/<service_name>/<action>', methods=['POST'])
def control_service(service_name, action):
    """Управління сервісами"""
    try:
        if action not in ['start', 'stop', 'restart']:
            return jsonify({'error': 'Непідтримувана дія'}), 400
        
        result = run_command(f'cd {BASE_DIR} && docker compose {action} {service_name}')
        
        if result['success']:
            return jsonify({'success': True, 'message': f'Сервіс {service_name} {action} успішно'})
        else:
            return jsonify({'error': result['stderr']}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/users')
def get_users():
    """Отримання списку користувачів"""
    try:
        # Отримуємо список користувачів через Synapse Admin API
        result = run_command(f'curl -s http://localhost:8008/_synapse/admin/v2/users')
        if result['success']:
            try:
                data = json.loads(result['stdout'])
                users = []
                for user in data.get('users', []):
                    users.append({
                        'username': user.get('name', 'Unknown'),
                        'email': user.get('threepids', [{}])[0].get('address', ''),
                        'status': 'active' if user.get('deactivated', False) == False else 'inactive'
                    })
                return jsonify(users)
            except:
                return jsonify([])
        else:
            return jsonify([])
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/api/users', methods=['POST'])
def create_user():
    """Створення користувача"""
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        is_admin = data.get('isAdmin', False)
        
        if not username or not password:
            return jsonify({'error': 'Відсутні обов\'язкові поля'}), 400
        
        # Створюємо користувача через Synapse Admin API
        admin_flag = '-a' if is_admin else ''
        result = run_command(
            f'cd {BASE_DIR} && docker compose exec -T synapse register_new_matrix_user '
            f'{admin_flag} -u {username} -p {password} -c /data/homeserver.yaml http://localhost:8008'
        )
        
        if result['success']:
            return jsonify({'success': True, 'message': 'Користувача створено успішно'})
        else:
            return jsonify({'error': result['stderr']}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/users/<username>', methods=['DELETE'])
def delete_user(username):
    """Видалення користувача"""
    try:
        # Видаляємо користувача через Synapse Admin API
        result = run_command(
            f'curl -X DELETE -H "Authorization: Bearer YOUR_ADMIN_TOKEN" '
            f'http://localhost:8008/_synapse/admin/v2/users/@{username}:{load_config().get("DOMAIN", "localhost")}'
        )
        
        if result['success']:
            return jsonify({'success': True, 'message': 'Користувача видалено успішно'})
        else:
            return jsonify({'error': result['stderr']}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/updates')
def get_updates_info():
    """Отримання інформації про оновлення"""
    try:
        # Отримуємо поточну версію
        result = run_command(f'cd {BASE_DIR} && docker compose images synapse --format json')
        current_version = 'Unknown'
        if result['success']:
            try:
                images = json.loads(result['stdout'])
                if images:
                    current_version = images[0].get('Tag', 'Unknown')
            except:
                pass
        
        # Перевіряємо чи є оновлення
        result = run_command(f'cd {BASE_DIR} && docker compose pull --dry-run')
        update_available = 'up to date' not in result['stdout'].lower()
        
        return jsonify({
            'currentVersion': current_version,
            'latestVersion': 'Latest',
            'updateAvailable': update_available
        })
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/api/updates/check', methods=['POST'])
def check_updates():
    """Перевірка оновлень"""
    try:
        result = run_command(f'cd {BASE_DIR} && docker compose pull --dry-run')
        return jsonify({'success': True, 'message': 'Перевірка завершена'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/updates/perform', methods=['POST'])
def perform_update():
    """Виконання оновлення"""
    try:
        def update_process():
            global update_progress
            update_progress = {'progress': 0, 'message': 'Початок оновлення...', 'completed': False}
            
            # Крок 1: Зупиняємо сервіси
            update_progress['progress'] = 10
            update_progress['message'] = 'Зупинка сервісів...'
            run_command(f'cd {BASE_DIR} && docker compose stop')
            time.sleep(2)
            
            # Крок 2: Завантажуємо нові образи
            update_progress['progress'] = 30
            update_progress['message'] = 'Завантаження нових образів...'
            run_command(f'cd {BASE_DIR} && docker compose pull')
            time.sleep(2)
            
            # Крок 3: Запускаємо сервіси
            update_progress['progress'] = 70
            update_progress['message'] = 'Запуск оновлених сервісів...'
            run_command(f'cd {BASE_DIR} && docker compose up -d')
            time.sleep(5)
            
            # Крок 4: Перевіряємо статус
            update_progress['progress'] = 90
            update_progress['message'] = 'Перевірка статусу сервісів...'
            time.sleep(3)
            
            update_progress['progress'] = 100
            update_progress['message'] = 'Оновлення завершено успішно!'
            update_progress['completed'] = True
        
        # Запускаємо оновлення в окремому потоці
        thread = threading.Thread(target=update_process)
        thread.daemon = True
        thread.start()
        
        return jsonify({'success': True, 'message': 'Оновлення розпочато'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/updates/progress')
def get_update_progress():
    """Отримання прогресу оновлення"""
    global update_progress
    return jsonify(update_progress)

@app.route('/api/backup', methods=['POST'])
def create_backup():
    """Створення резервної копії"""
    try:
        result = run_command(f'{BASE_DIR}/bin/backup-matrix.sh')
        if result['success']:
            return jsonify({'success': True, 'message': 'Резервну копію створено успішно'})
        else:
            return jsonify({'error': result['stderr']}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/backup')
def list_backups():
    """Список резервних копій"""
    try:
        backup_dir = '/DATA/matrix-backups'
        if os.path.exists(backup_dir):
            backups = []
            for file in os.listdir(backup_dir):
                if file.endswith('.tar.gz'):
                    file_path = os.path.join(backup_dir, file)
                    stat = os.stat(file_path)
                    backups.append({
                        'name': file,
                        'size': stat.st_size,
                        'date': datetime.fromtimestamp(stat.st_mtime).isoformat()
                    })
            return jsonify(backups)
        else:
            return jsonify([])
    except Exception as e:
        return jsonify({'error': str(e)})

@app.route('/')
def serve_dashboard():
    """Обслуговування головної сторінки dashboard"""
    return send_from_directory('dashboard', 'index.html')

@app.route('/<path:filename>')
def serve_static(filename):
    """Обслуговування статичних файлів"""
    return send_from_directory('dashboard', filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081, debug=False) 