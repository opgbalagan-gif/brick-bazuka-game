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
    sample: (gamma, beta = 30) => window.fire('deviceorientation', {gamma, beta}),
    timeout: () => {for (const fn of [...timers.values()]) fn();},
    permissionCalls: () => permissionCalls
  };
}
const flush = async () => {await Promise.resolve(); await Promise.resolve();};

const android = browser();
android.input.start();
assert.equal(android.input.needs_permission(), false);
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
assert.equal(android.input.read_axis(), 0, 'Each run starts with a fresh neutral position');

const iphone = browser({permission: () => Promise.resolve('granted')});
iphone.input.start();
assert(iphone.input.needs_permission());
assert.equal(iphone.permissionCalls(), 0, 'Do not request iPhone access outside a button click');
iphone.enable();
assert.equal(iphone.permissionCalls(), 1, 'Permission is requested synchronously in the click handler');
await flush();
assert.equal(iphone.input.needs_permission(), false);
iphone.sample(0); iphone.sample(22);
assert.equal(iphone.input.read_axis(), 1);
iphone.input.stop(); iphone.input.start();
assert.equal(iphone.permissionCalls(), 1, 'Granted access is reused between runs');

const denied = browser({permission: () => Promise.resolve('denied')});
denied.input.start(); denied.enable(); await flush();
assert.equal(denied.input.get_status(), 'denied');
denied.skip();
assert.equal(denied.input.needs_permission(), false);
const left = denied.elements.get('brick-tilt-left');
assert.equal(left.style.display, 'block');
left.fire('pointerdown'); assert.equal(denied.input.read_axis(), -1);
left.fire('pointercancel'); assert.equal(denied.input.read_axis(), 0, 'Cancelled touches release steering');
denied.input.stop(); assert.equal(left.style.display, 'none');

let resolvePermission;
const pending = browser({permission: () => new Promise(resolve => {resolvePermission = resolve;})});
pending.input.start(); pending.enable(); pending.skip();
resolvePermission('denied'); await flush();
assert.equal(pending.input.get_status(), 'buttons', 'A late permission result must not reopen the dialog after skipping');

for (const options of [{secure: false}, {supported: false}]) {
  const unavailable = browser(options);
  unavailable.input.start(); assert(unavailable.input.needs_permission());
  unavailable.skip(); assert.equal(unavailable.input.needs_permission(), false);
  unavailable.elements.get('brick-tilt-right').fire('pointerdown');
  assert.equal(unavailable.input.read_axis(), 1, 'Buttons work when sensor access is unavailable');
}
const silent = browser();
silent.input.start(); silent.timeout();
assert.equal(silent.input.get_status(), 'unavailable', 'No sensor events must offer fallback controls');
const desktop = browser({mobile: false});
desktop.input.start(); desktop.timeout();
assert.equal(desktop.input.needs_permission(), false, 'Desktop keyboard play must never be blocked by sensor prompts');
assert.equal(desktop.elements.get('brick-tilt-left').style.display, 'none');
console.log('TILT_WEB_TEST_OK calibration dead_zone left_right rotation permission fallback visibility lifecycle');
