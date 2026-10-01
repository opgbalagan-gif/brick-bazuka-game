/* Real browser input: tapping it opens the iOS/Android keyboard directly. */
(() => {
  'use strict';
  const fontStyle = document.createElement('style');
  fontStyle.textContent = "@font-face{font-family:BrickPixel;src:url('ui/Tiny5-Regular.ttf')}";
  document.body.appendChild(fontStyle);
  const input = document.createElement('input');
  input.id = 'brick-player-name';
  input.type = 'text';
  input.placeholder = 'Введи имя';
  input.maxLength = 20;
  input.autocomplete = 'nickname';
  input.enterKeyHint = 'done';
  input.setAttribute('aria-label', 'Твоё имя для рейтинга');
  input.style.cssText = 'position:fixed;display:none;z-index:24;box-sizing:border-box;background:transparent;color:#fff7e9;border:0;border-radius:0;padding:0;font-family:BrickPixel,monospace;text-shadow:1px 1px #000;outline:none;touch-action:manipulation;user-select:text;-webkit-user-select:text;';
  document.body.appendChild(input);
  const editButton = document.createElement('button');
  editButton.id = 'brick-edit-name';
  editButton.type = 'button';
  editButton.setAttribute('aria-label', 'Изменить имя');
  editButton.style.cssText = 'position:fixed;display:none;z-index:25;background:transparent;border:0;padding:0;cursor:pointer;touch-action:manipulation;';
  document.body.appendChild(editButton);
  let visible = false, submit = false, editRequested = false, rect = [0, 0, 0, 0];
  function beginEdit() {
    if (!visible) return;
    editRequested = true;
    input.readOnly = false;
    // A real DOM gesture must focus the real input synchronously on iOS.
    input.focus();
  }
  input.addEventListener('pointerdown', beginEdit);
  input.addEventListener('touchstart', beginEdit);
  editButton.addEventListener('click', event => {
    event.stopPropagation();
    if (input.readOnly) beginEdit();
    else { submit = true; input.blur(); }
  });
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
      fontSize: `${Math.max(16, 26 * scale)}px`, display: 'block'
    });
    Object.assign(editButton.style, {
      left: `${left + 372 * scale}px`, top: `${top + 226 * scale}px`,
      width: `${130 * scale}px`, height: `${54 * scale}px`, display: 'block'
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
    get_saved_name() { try { return localStorage.getItem('brick-player-name') || ''; } catch (_) { return ''; } },
    save_name(value) { try { localStorage.setItem('brick-player-name', String(value)); } catch (_) {} },
    open(value, editable) {
      input.value = String(value).slice(0, 20);
      input.readOnly = !editable;
      visible = true;
      submit = false;
      editRequested = false;
      place();
    },
    close() { visible = false; submit = false; editRequested = false; input.blur(); input.style.display = 'none'; editButton.style.display = 'none'; },
    place(x, y, width, height) { rect = [x, y, width, height]; place(); },
    get_value() { return input.value; },
    set_editable(value) {
      input.readOnly = !value;
      if (!value && document.activeElement === input) input.blur();
    },
    consume_edit() { const requested = editRequested; editRequested = false; return requested; },
    consume_submit() { const requested = submit; submit = false; return requested; }
  };
})();
