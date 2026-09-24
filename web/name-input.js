/* Real browser input: tapping it opens the iOS/Android keyboard directly. */
(() => {
  'use strict';
  const input = document.createElement('input');
  input.id = 'brick-player-name';
  input.type = 'text';
  input.placeholder = 'Введи имя';
  input.maxLength = 20;
  input.autocomplete = 'nickname';
  input.enterKeyHint = 'done';
  input.setAttribute('aria-label', 'Твоё имя для рейтинга');
  input.style.cssText = 'position:fixed;display:none;z-index:24;box-sizing:border-box;background:#061420;color:#f5f8ee;border:2px solid #80df41;border-radius:10px;padding:0 12px;font-family:Arial,sans-serif;outline:none;touch-action:manipulation;user-select:text;-webkit-user-select:text;';
  document.body.appendChild(input);
  let visible = false, submit = false, rect = [0, 0, 0, 0];
  function place() {
    const canvas = document.getElementById('canvas');
    if (!visible || !canvas || rect[2] <= 0) return;
    const bounds = canvas.getBoundingClientRect();
    const scale = Math.min(bounds.width / 540, bounds.height / 960);
    const left = bounds.left + (bounds.width - 540 * scale) / 2;
    const top = bounds.top + (bounds.height - 960 * scale) / 2;
    Object.assign(input.style, {
      left: `${left + rect[0] * scale}px`, top: `${top + rect[1] * scale}px`,
      width: `${rect[2] * scale}px`, height: `${rect[3] * scale}px`,
      fontSize: `${Math.max(16, 22 * scale)}px`, display: 'block'
    });
  }
  // Do not cancel default input events: selection, IME and the keyboard need them.
  for (const event of ['pointerdown', 'pointerup', 'touchstart', 'touchend', 'keydown', 'keyup']) {
    input.addEventListener(event, e => e.stopPropagation());
  }
  input.addEventListener('keydown', event => {
    if (event.key === 'Enter' && !event.isComposing) {
      event.preventDefault();
      submit = !input.readOnly;
      input.blur();
    }
  });
  window.addEventListener('resize', place);
  window.visualViewport?.addEventListener('resize', place);
  window.visualViewport?.addEventListener('scroll', place);
  window.BrickNameInput = {
    open(value, editable) {
      input.value = String(value).slice(0, 20);
      input.readOnly = !editable;
      visible = true;
      submit = false;
      place();
    },
    close() { visible = false; submit = false; input.blur(); input.style.display = 'none'; },
    place(x, y, width, height) { rect = [x, y, width, height]; place(); },
    get_value() { return input.value; },
    set_editable(value) {
      input.readOnly = !value;
      if (!value && document.activeElement === input) input.blur();
    },
    consume_submit() { const requested = submit; submit = false; return requested; }
  };
})();
