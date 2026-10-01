/* Motion input selected in Godot settings; iOS permission stays on a trusted DOM button. */
(() => {
  'use strict';
  const DEAD_ZONE = 3;
  const FULL_TILT = 22;
  const mobile = navigator.maxTouchPoints > 0;
  let active = false, listening = false, granted = false, buttonsOnly = true;
  let status = 'idle', axis = 0, neutral = null, sensitivity = 1;
  let sampleTimer = null, panelOpen = false;
  let permissionAttempt = 0;

  const style = document.createElement('style');
  style.textContent = `
    #canvas {touch-action:none}
    @font-face{font-family:BrickPixel;src:url('ui/Tiny5-Regular.ttf')}
    #brick-tilt-panel {position:fixed;inset:0;z-index:30;display:none;align-items:center;justify-content:center;background:#000c;font-family:BrickPixel,monospace;color:#fff7e9;padding:24px;box-sizing:border-box}
    #brick-tilt-card {width:370px;max-width:100%;padding:28px 20px;border:6px solid #ff7108;border-radius:16px;background:repeating-linear-gradient(45deg,#ffffff04 0 2px,transparent 2px 5px),#101518;text-align:center;box-sizing:border-box;box-shadow:0 0 0 4px #050607,inset 0 0 0 2px #050607}
    #brick-tilt-message {font-size:24px;line-height:1.25;margin:0 0 20px;text-shadow:2px 2px #000}
    #brick-tilt-panel button {position:relative;width:100%;min-height:54px;border-radius:9px;border:3px solid #050607;box-shadow:0 0 0 2px #ff8710;background:linear-gradient(#ff950b,#f25806);color:inherit;font:24px BrickPixel,monospace;text-shadow:2px 2px #000;margin:8px 0;padding:9px 14px;touch-action:manipulation;cursor:pointer}
    #brick-tilt-panel button::before,#brick-tilt-panel button::after {content:'';position:absolute;top:6px;width:9px;height:9px;border:2px solid #080b0d;border-radius:50%;background:linear-gradient(#f5f8fc,#687482);box-shadow:0 22px #74828d}
    #brick-tilt-panel button::before{left:5px}#brick-tilt-panel button::after{right:5px}
    #brick-tilt-panel button.secondary {background:#13191b;color:#b7f30c}
    #brick-tilt-panel button:focus-visible {outline:3px solid #b7f30c;outline-offset:4px}
    #brick-tilt-panel button:disabled {opacity:.6;cursor:wait}
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
  enable.id = 'brick-tilt-enable';
  const skip = document.createElement('button');
  skip.textContent = 'ИГРАТЬ ПАЛЬЦЕМ';
  skip.className = 'secondary';
  skip.id = 'brick-tilt-skip';
  card.append(message, enable, skip);
  panel.appendChild(card);
  document.body.appendChild(panel);

  function render() {
    panel.style.display = active && panelOpen ? 'flex' : 'none';
    const messages = {
      permission: 'Разреши наклон телефона для движения влево и вправо.',
      requesting: 'Ожидаем разрешение…',
      denied: 'Доступ к наклону не разрешён. Можно управлять пальцем и свайпом.',
      unavailable: 'Датчик наклона недоступен. Можно управлять пальцем и свайпом.',
      insecure: 'Для наклона открой игру по HTTPS. Здесь можно управлять пальцем и свайпом.'
    };
    message.textContent = messages[status] || messages.permission;
    enable.disabled = status === 'requesting';
    enable.style.display = ['unavailable', 'insecure'].includes(status) ? 'none' : 'block';
  }

  function orientation(event) {
    if (!active || document.hidden || buttonsOnly || !Number.isFinite(event.gamma) || !Number.isFinite(event.beta)) return;
    const degrees = screen.orientation?.angle ?? window.orientation ?? 0;
    const radians = degrees * Math.PI / 180;
    const roll = event.gamma * Math.cos(radians) + event.beta * Math.sin(radians);
    if (neutral === null) neutral = roll;
    const relative = roll - neutral;
    axis = Math.sign(relative) * Math.min(1, Math.max(0, Math.abs(relative) - DEAD_ZONE) * sensitivity / (FULL_TILT - DEAD_ZONE));
    status = 'active';
    panelOpen = false;
    clearTimeout(sampleTimer);
    render();
  }

  function recenter() {
    axis = 0;
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
    axis = 0;
    clearTimeout(sampleTimer);
    sampleTimer = setTimeout(() => {
      if (!active || status !== 'waiting') return;
      status = 'unavailable';
      panelOpen = true;
      render();
    }, 2500);
    render();
  }

  function start() {
    permissionAttempt++;
    active = true;
    axis = 0;
    if (buttonsOnly) {
      status = 'buttons';
      panelOpen = false;
      render();
    } else {
      startTilt();
    }
  }

  function startTilt() {
    buttonsOnly = false;
    axis = 0;
    if (!window.isSecureContext) {
      status = 'insecure';
      panelOpen = true;
    } else if (typeof window.DeviceOrientationEvent === 'undefined') {
      status = 'unavailable';
      panelOpen = true;
    } else if (typeof window.DeviceOrientationEvent.requestPermission === 'function' && !granted) {
      status = 'permission';
      panelOpen = true;
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
  function useTouch() {
    permissionAttempt++;
    buttonsOnly = true;
    stopListening();
    recenter();
    status = 'buttons';
    panelOpen = false;
    render();
  }
  skip.addEventListener('click', useTouch);
  document.addEventListener('visibilitychange', recenter);
  window.addEventListener('blur', recenter);
  window.addEventListener('orientationchange', recenter);
  screen.orientation?.addEventListener('change', recenter);

  window.BrickTilt = {
    start,
    set_mode(value) {
      const nextTouch = value !== 'tilt';
      if (nextTouch === buttonsOnly) return;
      permissionAttempt++;
      stopListening();
      recenter();
      if (nextTouch) { useTouch(); return; }
      buttonsOnly = false;
      if (active) startTilt();
    },
    get_mode() { return buttonsOnly ? 'touch' : 'tilt'; },
    set_sensitivity(value) {
      sensitivity = Number.isFinite(value) ? Math.min(1.4, Math.max(.7, value)) : 1;
    },
    calibrate() {
      recenter();
      if (active && !buttonsOnly && ['active', 'waiting'].includes(status)) listen();
    },
    stop() {
      permissionAttempt++;
      active = false;
      panelOpen = false;
      stopListening();
      axis = 0;
      render();
    },
    read_axis() { return active && !document.hidden && !panelOpen && !buttonsOnly ? axis : 0; },
    needs_permission() { return active && (panelOpen || (!buttonsOnly && status === 'waiting')); },
    is_mobile() { return mobile; },
    get_status() { return status; }
  };
})();
