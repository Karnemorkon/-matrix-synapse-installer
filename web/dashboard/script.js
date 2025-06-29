// JavaScript для Matrix Dashboard

class MatrixDashboard {
    constructor() {
        this.apiBase = '/api';
        this.currentSection = 'overview';
        this.updateInterval = null;
        this.init();
    }

    init() {
        this.setupNavigation();
        this.loadInitialData();
        this.setupEventListeners();
        this.startAutoRefresh();
    }

    setupNavigation() {
        const navLinks = document.querySelectorAll('.nav-link');
        navLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                const target = link.getAttribute('href').substring(1);
                this.showSection(target);
            });
        });
    }

    showSection(sectionId) {
        // Приховуємо всі секції
        document.querySelectorAll('.content-section').forEach(section => {
            section.classList.remove('active');
        });

        // Показуємо потрібну секцію
        const targetSection = document.getElementById(sectionId);
        if (targetSection) {
            targetSection.classList.add('active');
        }

        // Оновлюємо активне посилання
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
        });
        document.querySelector(`[href="#${sectionId}"]`).classList.add('active');

        this.currentSection = sectionId;
        this.loadSectionData(sectionId);
    }

    async loadInitialData() {
        await this.checkSystemStatus();
        await this.loadOverviewData();
    }

    async checkSystemStatus() {
        try {
            const response = await fetch(`${this.apiBase}/status`);
            const data = await response.json();
            
            const statusDot = document.querySelector('.status-dot');
            const statusText = document.querySelector('.status-text');
            
            if (data.status === 'online') {
                statusDot.className = 'status-dot online';
                statusText.textContent = 'Онлайн';
            } else {
                statusDot.className = 'status-dot offline';
                statusText.textContent = 'Офлайн';
            }
        } catch (error) {
            console.error('Помилка перевірки статусу:', error);
            const statusDot = document.querySelector('.status-dot');
            const statusText = document.querySelector('.status-text');
            statusDot.className = 'status-dot offline';
            statusText.textContent = 'Помилка підключення';
        }
    }

    async loadOverviewData() {
        try {
            const response = await fetch(`${this.apiBase}/overview`);
            const data = await response.json();
            
            document.getElementById('activeUsers').textContent = data.activeUsers || '0';
            document.getElementById('totalRooms').textContent = data.totalRooms || '0';
            document.getElementById('runningServices').textContent = data.runningServices || '0';
            document.getElementById('diskUsage').textContent = data.diskUsage || '0%';
        } catch (error) {
            console.error('Помилка завантаження даних огляду:', error);
        }
    }

    async loadSectionData(sectionId) {
        switch (sectionId) {
            case 'services':
                await this.loadServicesData();
                break;
            case 'users':
                await this.loadUsersData();
                break;
            case 'bridges':
                await this.loadBridgesData();
                break;
            case 'monitoring':
                await this.loadMonitoringData();
                break;
            case 'backup':
                await this.loadBackupData();
                break;
            case 'settings':
                await this.loadSettingsData();
                break;
            case 'updates':
                await this.loadUpdatesData();
                break;
        }
    }

    async loadServicesData() {
        try {
            const response = await fetch(`${this.apiBase}/services`);
            const services = await response.json();
            
            const servicesGrid = document.getElementById('servicesGrid');
            servicesGrid.innerHTML = '';
            
            services.forEach(service => {
                const serviceCard = this.createServiceCard(service);
                servicesGrid.appendChild(serviceCard);
            });
        } catch (error) {
            console.error('Помилка завантаження сервісів:', error);
        }
    }

    createServiceCard(service) {
        const card = document.createElement('div');
        card.className = 'service-card';
        card.innerHTML = `
            <div class="service-header">
                <span class="service-name">${service.name}</span>
                <span class="service-status ${service.status}">${service.status}</span>
            </div>
            <p>${service.description}</p>
            <div class="service-actions">
                <button class="btn btn-primary" onclick="dashboard.controlService('${service.name}', 'start')">
                    <i class="fas fa-play"></i> Запустити
                </button>
                <button class="btn btn-danger" onclick="dashboard.controlService('${service.name}', 'stop')">
                    <i class="fas fa-stop"></i> Зупинити
                </button>
                <button class="btn btn-secondary" onclick="dashboard.controlService('${service.name}', 'restart')">
                    <i class="fas fa-redo"></i> Перезапустити
                </button>
            </div>
        `;
        return card;
    }

    async controlService(serviceName, action) {
        try {
            const response = await fetch(`${this.apiBase}/services/${serviceName}/${action}`, {
                method: 'POST'
            });
            
            if (response.ok) {
                this.showNotification(`Сервіс ${serviceName} ${action} успішно`, 'success');
                await this.loadServicesData();
            } else {
                this.showNotification(`Помилка ${action} сервісу ${serviceName}`, 'error');
            }
        } catch (error) {
            console.error('Помилка управління сервісом:', error);
            this.showNotification('Помилка підключення до сервера', 'error');
        }
    }

    async loadUsersData() {
        try {
            const response = await fetch(`${this.apiBase}/users`);
            const users = await response.json();
            
            const usersTable = document.getElementById('usersTable');
            usersTable.innerHTML = `
                <table class="table">
                    <thead>
                        <tr>
                            <th>Користувач</th>
                            <th>Email</th>
                            <th>Статус</th>
                            <th>Дії</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${users.map(user => `
                            <tr>
                                <td>${user.username}</td>
                                <td>${user.email || '-'}</td>
                                <td><span class="service-status ${user.status}">${user.status}</span></td>
                                <td>
                                    <button class="btn btn-danger btn-sm" onclick="dashboard.deleteUser('${user.username}')">
                                        <i class="fas fa-trash"></i>
                                    </button>
                                </td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            `;
        } catch (error) {
            console.error('Помилка завантаження користувачів:', error);
        }
    }

    async createUser(userData) {
        try {
            const response = await fetch(`${this.apiBase}/users`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(userData)
            });
            
            if (response.ok) {
                this.showNotification('Користувача створено успішно', 'success');
                this.closeModal('createUserModal');
                await this.loadUsersData();
            } else {
                this.showNotification('Помилка створення користувача', 'error');
            }
        } catch (error) {
            console.error('Помилка створення користувача:', error);
            this.showNotification('Помилка підключення до сервера', 'error');
        }
    }

    async deleteUser(username) {
        if (confirm(`Ви впевнені, що хочете видалити користувача ${username}?`)) {
            try {
                const response = await fetch(`${this.apiBase}/users/${username}`, {
                    method: 'DELETE'
                });
                
                if (response.ok) {
                    this.showNotification('Користувача видалено успішно', 'success');
                    await this.loadUsersData();
                } else {
                    this.showNotification('Помилка видалення користувача', 'error');
                }
            } catch (error) {
                console.error('Помилка видалення користувача:', error);
                this.showNotification('Помилка підключення до сервера', 'error');
            }
        }
    }

    async loadUpdatesData() {
        try {
            const response = await fetch(`${this.apiBase}/updates`);
            const data = await response.json();
            
            document.getElementById('currentVersion').textContent = data.currentVersion || 'Невідомо';
            document.getElementById('latestVersion').textContent = data.latestVersion || 'Перевірка...';
            
            const updateBtn = document.getElementById('updateBtn');
            if (data.updateAvailable) {
                updateBtn.disabled = false;
                updateBtn.textContent = 'Оновити систему';
            } else {
                updateBtn.disabled = true;
                updateBtn.textContent = 'Система актуальна';
            }
        } catch (error) {
            console.error('Помилка завантаження інформації про оновлення:', error);
        }
    }

    async checkForUpdates() {
        try {
            const response = await fetch(`${this.apiBase}/updates/check`, {
                method: 'POST'
            });
            
            if (response.ok) {
                this.showNotification('Перевірка оновлень завершена', 'success');
                await this.loadUpdatesData();
            } else {
                this.showNotification('Помилка перевірки оновлень', 'error');
            }
        } catch (error) {
            console.error('Помилка перевірки оновлень:', error);
            this.showNotification('Помилка підключення до сервера', 'error');
        }
    }

    async performUpdate() {
        if (confirm('Ви впевнені, що хочете оновити систему? Це може зайняти кілька хвилин.')) {
            try {
                const response = await fetch(`${this.apiBase}/updates/perform`, {
                    method: 'POST'
                });
                
                if (response.ok) {
                    this.showNotification('Оновлення розпочато', 'success');
                    this.monitorUpdateProgress();
                } else {
                    this.showNotification('Помилка запуску оновлення', 'error');
                }
            } catch (error) {
                console.error('Помилка оновлення:', error);
                this.showNotification('Помилка підключення до сервера', 'error');
            }
        }
    }

    async monitorUpdateProgress() {
        const updateLog = document.getElementById('updateLog');
        updateLog.innerHTML = '<p>Оновлення в процесі...</p>';
        
        const checkProgress = async () => {
            try {
                const response = await fetch(`${this.apiBase}/updates/progress`);
                const data = await response.json();
                
                updateLog.innerHTML = `
                    <div class="update-progress">
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: ${data.progress}%"></div>
                        </div>
                        <p>${data.message}</p>
                        <p>Прогрес: ${data.progress}%</p>
                    </div>
                `;
                
                if (data.completed) {
                    this.showNotification('Оновлення завершено успішно', 'success');
                    await this.loadUpdatesData();
                    return;
                }
                
                setTimeout(checkProgress, 2000);
            } catch (error) {
                console.error('Помилка моніторингу оновлення:', error);
            }
        };
        
        checkProgress();
    }

    showModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.style.display = 'block';
        }
    }

    closeModal(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.style.display = 'none';
        }
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }

    startAutoRefresh() {
        this.updateInterval = setInterval(() => {
            this.checkSystemStatus();
            if (this.currentSection === 'overview') {
                this.loadOverviewData();
            }
        }, 30000); // Оновлення кожні 30 секунд
    }

    setupEventListeners() {
        // Модальні вікна
        document.querySelectorAll('.close').forEach(closeBtn => {
            closeBtn.addEventListener('click', () => {
                const modal = closeBtn.closest('.modal');
                if (modal) {
                    modal.style.display = 'none';
                }
            });
        });

        // Форма створення користувача
        const createUserForm = document.getElementById('createUserForm');
        if (createUserForm) {
            createUserForm.addEventListener('submit', (e) => {
                e.preventDefault();
                const formData = new FormData(createUserForm);
                const userData = {
                    username: formData.get('username'),
                    password: formData.get('password'),
                    isAdmin: formData.get('isAdmin') === 'on'
                };
                this.createUser(userData);
            });
        }
    }
}

// Глобальні функції для виклику з HTML
function showCreateUserModal() {
    dashboard.showModal('createUserModal');
}

function createBackup() {
    dashboard.createBackup();
}

function listBackups() {
    dashboard.listBackups();
}

function checkForUpdates() {
    dashboard.checkForUpdates();
}

function performUpdate() {
    dashboard.performUpdate();
}

function saveSettings() {
    dashboard.saveSettings();
}

// Ініціалізація dashboard
const dashboard = new MatrixDashboard(); 