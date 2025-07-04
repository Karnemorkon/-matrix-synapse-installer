// --- Перемикач теми (світла/темна) ---
const themeToggle = document.getElementById('theme-toggle');
const body = document.body;

// Встановлюємо тему з localStorage або за замовчуванням світлу
function setTheme(theme) {
  if (theme === 'dark') {
    body.classList.add('dark');
    themeToggle.textContent = '☀️';
  } else {
    body.classList.remove('dark');
    themeToggle.textContent = '🌙';
  }
  localStorage.setItem('theme', theme);
}

const savedTheme = localStorage.getItem('theme') || 'light';
setTheme(savedTheme);

themeToggle.addEventListener('click', () => {
  const newTheme = body.classList.contains('dark') ? 'light' : 'dark';
  setTheme(newTheme);
});

// --- Функція для показу/приховування помилки API ---
// Показує або ховає повідомлення про помилку API
function showApiError(show) {
  document.getElementById('api-error').classList.toggle('hidden', !show);
}

// --- Завантаження статусу системи ---
// Оновлює статус системи через API
async function loadStatus() {
  try {
    const res = await fetch('/api/status');
    if (!res.ok) throw new Error('API недоступний');
    const data = await res.json();
    document.getElementById('status-content').textContent = `Стан: ${data.status === 'online' ? '🟢 Онлайн' : '🔴 Офлайн'}`;
    showApiError(false);
  } catch (e) {
    document.getElementById('status-content').textContent = 'Немає даних';
    showApiError(true);
  }
}

// --- Завантаження сервісів ---
// Оновлює список сервісів через API
async function loadServices() {
  try {
    const res = await fetch('/api/services');
    if (!res.ok) throw new Error('API недоступний');
    const services = await res.json();
    const html = services.map(s => `
      <div class="service-row">
        <b>${s.name}</b>: ${s.status === 'running' ? '🟢' : '🔴'}
        <button onclick="serviceAction('${s.name}','start')">Старт</button>
        <button onclick="serviceAction('${s.name}','stop')">Стоп</button>
        <button onclick="serviceAction('${s.name}','restart')">Рестарт</button>
      </div>
    `).join('');
    document.getElementById('services-list').innerHTML = html;
    showApiError(false);
  } catch (e) {
    document.getElementById('services-list').textContent = 'Немає даних';
    showApiError(true);
  }
}

// --- Дії над сервісами ---
// Запускає/зупиняє/перезапускає сервіс через API
window.serviceAction = async (name, action) => {
  try {
    const res = await fetch(`/api/services/${name}/${action}`, {method: 'POST'});
    if (!res.ok) throw new Error('API недоступний');
    await loadServices();
  } catch (e) {
    alert('Помилка виконання дії!');
  }
};

// --- Завантаження користувачів ---
// Оновлює список користувачів через API
async function loadUsers() {
  try {
    const res = await fetch('/api/users');
    if (!res.ok) throw new Error('API недоступний');
    const users = await res.json();
    const html = users.map(u => `
      <div class="user-row">
        <b>${u.username}</b> (${u.status})
        <button onclick="deleteUser('${u.username}')">Видалити</button>
      </div>
    `).join('');
    document.getElementById('users-list').innerHTML = html;
    showApiError(false);
  } catch (e) {
    document.getElementById('users-list').textContent = 'Немає даних';
    showApiError(true);
  }
}

// --- Створення користувача ---
document.getElementById('user-create-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const username = document.getElementById('new-username').value.trim();
  const password = document.getElementById('new-password').value;
  if (!username || !password) return;
  try {
    const res = await fetch('/api/users', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({username, password})
    });
    if (!res.ok) throw new Error('API недоступний');
    document.getElementById('new-username').value = '';
    document.getElementById('new-password').value = '';
    await loadUsers();
  } catch (e) {
    alert('Помилка створення користувача!');
  }
});

// --- Видалення користувача ---
// Видаляє користувача через API
window.deleteUser = async (username) => {
  if (!confirm(`Видалити користувача ${username}?`)) return;
  try {
    const res = await fetch(`/api/users/${username}`, {method: 'DELETE'});
    if (!res.ok) throw new Error('API недоступний');
    await loadUsers();
  } catch (e) {
    alert('Помилка видалення користувача!');
  }
};

// --- Завантаження резервних копій ---
// Оновлює список бекапів через API
async function loadBackups() {
  try {
    const res = await fetch('/api/backup');
    if (!res.ok) throw new Error('API недоступний');
    const backups = await res.json();
    const html = backups.map(b => `
      <div class="backup-row">
        <b>${b.name}</b> (${(b.size/1024/1024).toFixed(1)} MB, ${b.date})
      </div>
    `).join('');
    document.getElementById('backup-list').innerHTML = html;
    showApiError(false);
  } catch (e) {
    document.getElementById('backup-list').textContent = 'Немає даних';
    showApiError(true);
  }
}

// --- Створення резервної копії ---
// Створює новий бекап через API
document.getElementById('backup-create').addEventListener('click', async () => {
  try {
    const res = await fetch('/api/backup', {method: 'POST'});
    if (!res.ok) throw new Error('API недоступний');
    await loadBackups();
  } catch (e) {
    alert('Помилка створення резервної копії!');
  }
});

// --- Ініціалізація ---
// Запускає всі основні завантаження при старті сторінки
function init() {
  loadStatus();
  loadServices();
  loadUsers();
  loadBackups();
}

window.addEventListener('DOMContentLoaded', init); 