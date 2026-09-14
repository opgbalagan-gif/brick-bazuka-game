/* Phone tilt input for the Godot Web build. No sensor data leaves this page. */
(() => {
  'use strict';
  const DEAD_ZONE = 3;
  const FULL_TILT = 22;
  const mobile = navigator.maxTouchPoints > 0;
  let active = false, listening = false, granted = false, buttonsOnly = false;
  let status = 'idle', axis = 0, buttonAxis = 0, neutral = null;
  let sampleTimer = null, panelOpen = false;
  let permissionAttempt = 0;

  const style = document.createElement('style');
  style.textContent = `
    #brick-tilt-panel {position:fixed;inset:0;z-index:30;display:none;align-items:center;justify-content:center;background:#000b;font-family:Arial,sans-serif;color:#f5f8ee;padding:24px;box-sizing:border-box}
    #brick-tilt-card {width:320px;max-width:100%;padding:24px;border:2px solid #80df41;border-radius:14px;background:#071f38;text-align:center;box-sizing:border-box}
    #brick-tilt-message {font-size:19px;line-height:1.4;margin:0 0 18px}
    #brick-tilt-panel button {width:100%;min-height:48px;border-radius:9px;border:1px solid #80df41;background:#287f29;color:inherit;font-size:16px;margin:5px 0;touch-action:manipulation}
    #brick-tilt-panel button.secondary {background:#12334b;border-color:#355c70}
    .brick-tilt-arrow {position:fixed;bottom:18px;z-index:25;width:58px;height:58px;border:2px solid #80df41;border-radius:12px;background:#071f38dd;color:#f5f8ee;font:30px Arial;touch-action:none;user-select:none;-webkit-user-select:none;display:none}
    #brick-tilt-left {left:12px} #brick-tilt-right {right:12px}
  `;
  document.head.appendChild(style);
  const panel = document.createElement('div');
  panel.id = 'brick-tilt-panel';
  panel.setAttribute('role', 'dialog');
  panel.setAttribute('aria-label', 'Управление наклоном');
  const card = document.createElement('div');
  card.id = 'brick-tilt-card';
  const message = document.createElement('p');
  message.id = 'brick-tilt-message';
  const enable = document.createElement('button');
  enable.textContent = 'ВКЛЮЧИТЬ НАКЛОН';
  const skip = document.createElement('button');
  skip.textContent = 'ИГРАТЬ КНОПКАМИ';
  skip.className = 'secondary';
  card.append(message, enable, skip);
  panel.appendChild(card);
  document.body.appendChild(panel);

  const arrows = [-1, 1].map(direction => {
    const button = document.createElement('button');
    button.id = direction < 0 ? 'brick-tilt-left' : 'brick-tilt-right';
    button.className = 'brick-tilt-arrow';
    button.textContent = direction < 0 ? '←' : '→';
    button.setAttribute('aria-label', direction < 0 ? 'Двигаться влево' : 'Двигаться вправо');
    button.addEventListener('pointerdown', event => {
      event.preventDefault();
      event.stopPropagation();
      button.setPointerCapture(event.pointerId);
      buttonAxis = direction;
    });
    const release = event => {
      event.preventDefault();
      event.stopPropagation();
      if (buttonAxis === direction) buttonAxis = 0;
    };
    button.addEventListener('pointerup', release);
    button.addEventListener('pointercancel', release);
    button.addEventListener('lostpointercapture', release);
    document.body.appendChild(button);
    return button;
  });

  function render() {
    panel.style.display = active && panelOpen && mobile ? 'flex' : 'none';
    const messages = {
      permission: 'Разреши наклон телефона для движения влево и вправо.',
      requesting: 'Ожидаем разрешение…',
      denied: 'Доступ к наклону не разрешён. Можно играть кнопками.',
      unavailable: 'Датчик наклона недоступен. Можно играть кнопками.',
      insecure: 'Для наклона открой игру по HTTPS. Здесь можно играть кнопками.'
    };
    message.textContent = messages[status] || messages.permission;
    enable.disabled = status === 'requesting';
    enable.style.display = ['unavailable', 'insecure'].includes(status) ? 'none' : 'block';
    arrows.forEach(button => {
      button.style.display = active && mobile && !panelOpen && status !== 'active' ? 'block' : 'none';
    });
  }

  function orientation(event) {
    if (!active || document.hidden || buttonsOnly || !Number.isFinite(event.gamma) || !Number.isFinite(event.beta)) return;
    const degrees = screen.orientation?.angle ?? window.orientation ?? 0;
    const radians = degrees * Math.PI / 180;
    const roll = event.gamma * Math.cos(radians) + event.beta * Math.sin(radians);
    if (neutral === null) neutral = roll;
    const relative = roll - neutral;
    axis = Math.sign(relative) * Math.min(1, Math.max(0, Math.abs(relative) - DEAD_ZONE) / (FULL_TILT - DEAD_ZONE));
    status = 'active';
    panelOpen = false;
    clearTimeout(sampleTimer);
    render();
  }

  function recenter() {
    axis = 0;
    buttonAxis = 0;
    neutral = null;
  }

  function stopListening() {
    clearTimeout(sampleTimer);
    if (listening) window.removeEventListener('deviceorientation', orientation);
    listening = false;
  }

  function listen() {
    if (!active || buttonsOnly) return;
    if (!listening) window.addEventListener('deviceorientation', orientation);
    listening = true;
    status = 'waiting';
    panelOpen = false;
    recenter();
    clearTimeout(sampleTimer);
    sampleTimer = setTimeout(() => {
      if (!active || status !== 'waiting') return;
      status = 'unavailable';
      panelOpen = mobile;
      render();
    }, 2500);
    render();
  }

  function start() {
    permissionAttempt++;
    active = true;
    recenter();
    if (buttonsOnly) {
      status = 'buttons';
      panelOpen = false;
    } else if (!window.isSecureContext) {
      status = 'insecure';
      panelOpen = mobile;
    } else if (typeof window.DeviceOrientationEvent === 'undefined') {
      status = 'unavailable';
      panelOpen = mobile;
    } else if (typeof window.DeviceOrientationEvent.requestPermission === 'function' && !granted) {
      status = 'permission';
      panelOpen = mobile;
    } else {
      listen();
    }
    render();
  }

  // Must run directly in a trusted DOM click, before any await (iPhone/Safari).
  enable.addEventListener('click', () => {
    if (!active || status === 'requesting') return;
    buttonsOnly = false;
    const permission = window.DeviceOrientationEvent?.requestPermission;
    if (typeof permission !== 'function') { listen(); return; }
    status = 'requesting';
    const attempt = ++permissionAttempt;
    render();
    try {
      const result = permission.call(window.DeviceOrientationEvent);
      Promise.resolve(result).then(value => {
        if (attempt !== permissionAttempt) return;
        granted = value === 'granted';
        if (granted) listen();
        else { status = 'denied'; panelOpen = active; render(); }
      }).catch(() => {
        if (attempt !== permissionAttempt) return;
        status = 'denied'; panelOpen = active; render();
      });
    } catch (_) {
      status = 'denied';
      panelOpen = true;
      render();
    }
  });
  skip.addEventListener('click', () => {
    permissionAttempt++;
    buttonsOnly = true;
    stopListening();
    recenter();
    status = 'buttons';
    panelOpen = false;
    render();
  });
  document.addEventListener('visibilitychange', recenter);
  window.addEventListener('blur', recenter);
  window.addEventListener('orientationchange', recenter);
  screen.orientation?.addEventListener('change', recenter);

  window.BrickTilt = {
    start,
    stop() {
      permissionAttempt++;
      active = false;
      panelOpen = false;
      stopListening();
      recenter();
      render();
    },
    read_axis() { return active && !document.hidden && !panelOpen ? buttonAxis || axis : 0; },
    needs_permission() { return active && mobile && panelOpen; },
    get_status() { return status; }
  };
})();
