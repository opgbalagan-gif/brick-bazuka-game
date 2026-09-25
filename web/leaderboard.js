(() => {
  'use strict';
  const api = document.querySelector('meta[name="brick-api"]').content;
  const table = document.getElementById('scores'), empty = document.getElementById('empty');
  const status = document.getElementById('board-status'), nameStatus = document.getElementById('name-status');
  const input = document.getElementById('player-name'), edit = document.getElementById('edit-name');
  let cached = null, timer = null, busy = false, failures = 0;
  const read = key => { try { return localStorage.getItem(key); } catch (_) { return null; } };
  const write = (key, value) => { try { localStorage.setItem(key, value); return true; } catch (_) { return false; } };
  const valid = name => name.length >= 2 && name.length <= 20 && !/^[=+@\-']|[<>\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]/u.test(name);
  input.value = read('brick-player-name') || '';
  input.readOnly = valid(input.value);
  edit.textContent = input.readOnly ? 'Изменить' : 'Готово';
  input.addEventListener('input', () => { if (valid(input.value.trim())) write('brick-player-name', input.value.trim()); });
  document.getElementById('profile-form').addEventListener('submit', event => {
    event.preventDefault();
    if (input.readOnly) { input.readOnly = false; edit.textContent = 'Готово'; input.focus(); input.select(); return; }
    const value = input.value.trim();
    if (!valid(value)) { nameStatus.textContent = 'Введи имя от 2 до 20 символов без служебных знаков.'; return; }
    input.value = value;
    nameStatus.textContent = write('brick-player-name', value) ? 'Имя сохранено на этом устройстве.' : 'Браузер не разрешил сохранить имя.';
    input.readOnly = true; edit.textContent = 'Изменить'; input.blur();
  });
  function draw(data, live = false) {
    if (!data || data.game !== 'brick-bazuka' || !Array.isArray(data.rows)) return false;
    if (!live && cached && Date.parse(cached.updatedAt) > Date.parse(data.updatedAt)) return false;
    cached = data; table.replaceChildren();
    for (const row of data.rows.slice(0, 10)) {
      const line = document.createElement('tr');
      for (const value of [row.rank, row.name, row.score]) { const cell = document.createElement('td'); cell.textContent = String(value ?? ''); line.appendChild(cell); }
      table.appendChild(line);
    }
    empty.hidden = data.rows.length > 0; empty.textContent = 'Пока нет результатов. Стань первым!';
    const date = new Date(data.updatedAt);
    const stamp = Number.isFinite(date.getTime()) ? date.toLocaleString('ru-RU') : 'дата неизвестна';
    status.textContent = `${live ? 'Обновлено' : 'Последняя загруженная таблица'}: ${stamp}`;
    return true;
  }
  async function refresh() {
    if (busy || document.hidden) return;
    clearTimeout(timer); busy = true;
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const response = await fetch(`${api}?action=brick_leaderboard&t=${Date.now()}`, {cache:'no-store', credentials:'omit', redirect:'follow', signal:controller.signal});
      if (!response.ok) throw new Error('HTTP');
      const data = await response.json();
      if (!draw(data, true)) throw new Error('Invalid leaderboard');
      write('brick-board-cache', JSON.stringify(data)); failures = 0;
    } catch (_) {
      failures++;
      if (cached) { draw(cached); status.textContent += ' · Нет связи, переподключаемся…'; }
      else status.textContent = 'Не удалось подключиться. Повторяем автоматически…';
    } finally {
      clearTimeout(timeout); busy = false;
      timer = setTimeout(refresh, failures ? Math.min(30000, 2000 * 2 ** Math.min(failures - 1, 4)) : 15000);
    }
  }
  try { draw(JSON.parse(read('brick-board-cache'))); } catch (_) {}
  fetch('leaderboard-snapshot.json', {cache:'no-cache'}).then(r => r.json()).then(data => draw(data)).catch(() => {});
  document.getElementById('refresh').addEventListener('click', refresh);
  window.addEventListener('online', refresh);
  document.addEventListener('visibilitychange', () => { if (document.hidden) clearTimeout(timer); else refresh(); });
  refresh();
})();
