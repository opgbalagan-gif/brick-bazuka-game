import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const elements = new Map();
class Target {
  listeners = new Map();
  addEventListener(event, fn) { const list = this.listeners.get(event) || []; list.push(fn); this.listeners.set(event, list); }
  fire(event, data = {}) { const e = {stopped: false, prevented: false, stopPropagation() {this.stopped = true;}, preventDefault() {this.prevented = true;}, ...data}; for (const fn of this.listeners.get(event) || []) fn(e); return e; }
}
class Element extends Target {
  style = {}; value = ''; readOnly = false;
  set id(value) {elements.set(value, this);}
  setAttribute() {}
  blur() { if (document.activeElement === this) document.activeElement = null; }
}
let bounds = {left: 100, top: 20, width: 540, height: 960};
elements.set('canvas', {getBoundingClientRect: () => bounds});
const document = {activeElement: null, body: {appendChild() {}}, createElement: () => new Element(), getElementById: id => elements.get(id)};
const window = Object.assign(new Target(), {visualViewport: new Target()});
vm.runInNewContext(readFileSync(new URL('../web/name-input.js', import.meta.url), 'utf8'), {document, window});
const bridge = window.BrickNameInput, input = elements.get('brick-player-name');
bridge.place(54, 239, 258, 48);
bridge.open('', true);
assert.equal(input.style.left, '154px');
assert.equal(input.style.top, '259px');
assert.equal(input.maxLength, 20);
assert.equal(input.readOnly, false);
input.value = 'Тимбер 42';
document.activeElement = input;
assert.equal(bridge.get_value(), 'Тимбер 42');
assert(input.fire('touchstart').stopped);
assert.equal(input.fire('touchstart').prevented, false, 'Tapping must keep the native keyboard behavior');
input.fire('keydown', {key: 'Enter', isComposing: true});
assert.equal(bridge.consume_submit(), false, 'IME composition must not prematurely submit');
input.fire('keydown', {key: 'Enter'});
assert.equal(bridge.consume_submit(), true);
assert.equal(bridge.consume_submit(), false, 'One Enter must enqueue only one submission');
bridge.set_editable(false);
input.fire('keydown', {key: 'Enter'});
assert.equal(bridge.consume_submit(), false, 'A submitted score must not submit twice');
bridge.set_editable(true);
bounds = {left: 0, top: 0, width: 1080, height: 960};
window.fire('resize');
assert.equal(input.style.left, '324px', 'Input must follow the letterboxed game, not the canvas edge');
bounds = {left: 0, top: 0, width: 360, height: 640};
window.visualViewport.fire('resize');
assert.equal(input.style.left, '36px');
assert.equal(input.style.fontSize, '16px', 'Phone text must avoid automatic focus zoom');
bridge.close();
assert.equal(input.style.display, 'none');
assert.equal(document.activeElement, null);
bridge.open('Ещё забег', true);
assert.equal(bridge.get_value(), 'Ещё забег');
assert.equal(input.readOnly, false);
console.log('NAME_INPUT_TEST_OK Cyrillic native_keyboard IME submit_once resize letterbox hide restart');
