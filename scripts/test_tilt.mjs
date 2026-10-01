import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

function browser({mobile = true, secure = true, supported = true, permission} = {}) {
  const elements = new Map(), timers = new Map();
  let timerId = 0, permissionCalls = 0;
  class Target {
    listeners = new Map();
    addEventListener(name, fn) {
      if (!this.listeners.has(name)) this.listeners.set(name, new Set());
      this.listeners.get(name).add(fn);
    }
    removeEventListener(name, fn) { this.listeners.get(name)?.delete(fn); }
    fire(name, value = {}) {
      const event = {preventDefault() {}, stopPropagation() {}, pointerId: 1, ...value};
      for (const fn of this.listeners.get(name) || []) fn(event);
    }
  }
  class Element extends Target {
    style = {};
    children = [];
    set id(value) { elements.set(value, this); }
    setAttribute() {}
    append(...items) { this.children.push(...items); }
    appendChild(item) { this.children.push(item); }
    setPointerCapture() {}
  }
  const document = Object.assign(new Target(), {hidden: false, head: new Element(), body: new Element(), createElement: () => new Element()});
  const screen = {orientation: Object.assign(new Target(), {angle: 0})};
  const window = Object.assign(new Target(), {isSecureContext: secure});
  if (supported) {
    window.DeviceOrientationEvent = class {};
    if (permission) window.DeviceOrientationEvent.requestPermission = () => {permissionCalls++; return permission();};
  }
  vm.runInNewContext(readFileSync(new URL('../web/tilt-control.js', import.meta.url), 'utf8'), {
    window, document, screen, navigator: {maxTouchPoints: mobile ? 1 : 0},
    setTimeout: fn => {timers.set(++timerId, fn); return timerId;}, clearTimeout: id => timers.delete(id)
  });
  const card = elements.get('brick-tilt-card');
  return {
    input: window.BrickTilt, window, document, screen, elements,
    enable: () => card.children[1].fire('click'), skip: () => card.children[2].fire('click'),
    toggle: () => window.BrickTilt.set_mode(window.BrickTilt.get_mode() === 'tilt' ? 'touch' : 'tilt'),
    sample: (gamma, beta = 30) => window.fire('deviceorientation', {gamma, beta}),
    timeout: () => {for (const fn of [...timers.values()]) fn();},
    permissionCalls: () => permissionCalls
  };
}
const flush = async () => {await Promise.resolve(); await Promise.resolve();};

const android = browser();
android.input.start();
assert.equal(android.input.needs_permission(), false);
assert.equal(android.input.get_status(), 'buttons', 'Phones must start in touch mode without a sensor prompt');
for (const id of ['brick-tilt-left', 'brick-tilt-right', 'brick-control-mode']) {
  assert.equal(android.elements.has(id), false, 'Tilt choices must live in settings, without extra gameplay buttons');
}
android.sample(0); android.sample(22);
assert.equal(android.input.read_axis(), 0, 'Touch mode must ignore sensor movement');
android.toggle();
android.sample(null);
assert.equal(android.input.read_axis(), 0, 'Missing sensor data must not move the hero');
android.sample(8);
assert.equal(android.input.read_axis(), 0, 'The initial phone position is neutral');
android.sample(10);
assert.equal(android.input.read_axis(), 0, 'Small hand tremors stay in the dead zone');
android.sample(30);
assert.equal(android.input.read_axis(), 1, 'Tilting right gives full right input');
android.sample(-14);
assert.equal(android.input.read_axis(), -1, 'Tilting left gives full left input');
android.document.hidden = true;
android.document.fire('visibilitychange');
assert.equal(android.input.read_axis(), 0, 'Hidden tabs cannot retain steering');
android.document.hidden = false;
android.sample(15);
assert.equal(android.input.read_axis(), 0, 'Returning to the game recalibrates');
android.screen.orientation.angle = 90;
android.screen.orientation.fire('change');
android.sample(15, 20);
android.sample(15, 42);
assert.equal(android.input.read_axis(), 1, 'Landscape uses its horizontal sensor axis');
android.input.stop();
android.sample(-40);
assert.equal(android.input.read_axis(), 0);
assert.equal(android.window.listeners.get('deviceorientation').size, 0, 'Menu stops the sensor listener');
android.input.start();
android.sample(-25, 40);
assert(android.input.read_axis() > .85, 'The calibrated center must survive closing settings and resuming');
android.input.calibrate();
android.sample(-25, 40);
assert.equal(android.input.read_axis(), 0, 'Center must use the current comfortable phone position');
android.input.set_sensitivity(.7);
android.sample(-25, 52);
const gentle = android.input.read_axis();
android.input.set_sensitivity(1.4);
android.sample(-25, 52);
assert(android.input.read_axis() > gentle * 1.9, 'Sensitivity must affect real sensor input');

const iphone = browser({permission: () => Promise.resolve('granted')});
iphone.input.start();
assert.equal(iphone.input.needs_permission(), false, 'iPhone touch play must not require motion permission');
iphone.toggle();
assert(iphone.input.needs_permission());
assert.equal(iphone.permissionCalls(), 0, 'Do not request iPhone access outside a button click');
iphone.enable();
assert.equal(iphone.permissionCalls(), 1, 'Permission is requested synchronously in the click handler');
await flush();
assert.equal(iphone.input.needs_permission(), true, 'Wait for a real sensor sample before releasing the game');
iphone.sample(0); iphone.sample(22);
assert.equal(iphone.input.needs_permission(), false);
assert.equal(iphone.input.read_axis(), 1);
iphone.input.stop(); iphone.input.start();
assert.equal(iphone.permissionCalls(), 1, 'Granted access is reused between runs');

const denied = browser({permission: () => Promise.resolve('denied')});
denied.input.start(); denied.toggle(); denied.enable(); await flush();
assert.equal(denied.input.get_status(), 'denied');
denied.skip();
assert.equal(denied.input.needs_permission(), false);
assert.equal(denied.input.get_mode(), 'touch', 'Fallback must report its selected mode to the saved Godot setting');
assert.equal(denied.input.read_axis(), 0, 'Fallback must release sensor input');
denied.input.stop();

let resolvePermission;
const pending = browser({permission: () => new Promise(resolve => {resolvePermission = resolve;})});
pending.input.start(); pending.toggle(); pending.enable(); pending.skip();
resolvePermission('denied'); await flush();
assert.equal(pending.input.get_status(), 'buttons', 'A late permission result must not reopen the dialog after skipping');

for (const options of [{secure: false}, {supported: false}]) {
  const unavailable = browser(options);
  unavailable.input.start(); assert.equal(unavailable.input.needs_permission(), false);
  unavailable.toggle(); assert(unavailable.input.needs_permission());
  unavailable.skip(); assert.equal(unavailable.input.needs_permission(), false);
  assert.equal(unavailable.input.get_mode(), 'touch', 'Unsupported sensors must offer finger controls');
}
const silent = browser();
silent.input.start(); silent.toggle(); silent.timeout();
assert.equal(silent.input.get_status(), 'unavailable', 'No sensor events must offer fallback controls');
const desktop = browser({mobile: false});
assert.equal(desktop.input.is_mobile(), false, 'Desktop builds must select the keyboard tutorial');
assert.equal(android.input.is_mobile(), true, 'Phones must retain the touch tutorial');
desktop.input.start(); desktop.timeout();
assert.equal(desktop.input.needs_permission(), false, 'Desktop keyboard play must never be blocked by sensor prompts');
assert.equal(desktop.elements.has('brick-tilt-left'), false);
assert.equal(desktop.elements.has('brick-control-mode'), false);
desktop.input.set_mode('tilt'); desktop.timeout();
assert.equal(desktop.input.needs_permission(), true, 'Explicit tilt on a device without samples must offer a way back');
desktop.skip(); assert.equal(desktop.input.needs_permission(), false);
iphone.sample(0); iphone.sample(22);
iphone.toggle();
assert.equal(iphone.input.get_status(), 'buttons');
assert.equal(iphone.input.read_axis(), 0, 'Switching back to touch must clear tilt input');
assert.equal(iphone.window.listeners.get('deviceorientation').size, 0, 'Touch mode must stop sensors');
iphone.input.stop(); iphone.input.start();
assert.equal(iphone.input.get_status(), 'buttons', 'The selected touch mode must survive a restart');
const restored = browser({permission: () => Promise.resolve('granted')});
restored.input.set_mode('tilt');
assert.equal(restored.permissionCalls(), 0, 'Restoring the preference must not automatically request permission');
assert.equal(restored.input.needs_permission(), false, 'A restored mode must stay inactive in the menu');
restored.input.start();
assert.equal(restored.input.needs_permission(), true);
restored.input.stop();
assert.equal(restored.input.needs_permission(), false, 'Leaving settings must close the permission UI');
console.log('TILT_WEB_TEST_OK settings_mode saved_preference calibration_survives_pause sensitivity touch_default dead_zone left_right rotation trusted_permission fallback visibility lifecycle');
