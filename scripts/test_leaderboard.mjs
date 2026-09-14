import assert from 'node:assert/strict';
import { createHmac, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import vm from 'node:vm';

export function createSandbox() {
  const properties = new Map([['SIGNING_KEY', 'isolated-test-key'], ['SPREADSHEET_ID', 'sollers-test']]);
  const cache = new Map(), sheets = new Map();
  function makeSheet() {
    const rows = [];
    const sheet = {
      rows, getLastRow: () => rows.length + 1,
      appendRow: row => rows.push(row),
      setName() {}, setFrozenRows() {}, setColumnWidth() {},
      getRange(row, col, count, columns) {
        const range = {
          getValues: () => rows.slice(row - 2, row - 2 + count).map(r => r.slice(col - 1, col - 1 + columns)),
          createTextFinder: value => ({matchEntireCell() {return this;}, findNext() {
            const index = rows.findIndex(r => r[col - 1] === value);
            return index < 0 ? null : {getRow: () => index + 2};
          }}),
        };
        for (const name of ['setValues', 'setFontWeight', 'setBackground', 'setFontColor', 'setNumberFormat']) range[name] = () => range;
        return range;
      },
    };
    return sheet;
  }
  sheets.set('sollers-test', makeSheet());
  const state = {busy: false};
  const runtime = vm.createContext({
    console: {log() {}}, Date,
    PropertiesService: {getScriptProperties: () => ({getProperty: key => properties.get(key), setProperty: (key, value) => properties.set(key, value)})},
    CacheService: {getScriptCache: () => ({get: key => cache.get(key), put: (key, value) => cache.set(key, value), remove: key => cache.delete(key)})},
    LockService: {getScriptLock: () => ({tryLock: () => !state.busy, releaseLock() {}})},
    SpreadsheetApp: {
      openById: id => ({getSheetByName: () => sheets.get(id)}), flush() {},
      create() {const id = randomUUID(); sheets.set(id, makeSheet()); return {getId: () => id, getSheets: () => [sheets.get(id)]};},
    },
    Utilities: {getUuid: randomUUID, computeHmacSha256Signature: (message, key) => createHmac('sha256', key).update(message).digest(), base64EncodeWebSafe: bytes => Buffer.from(bytes).toString('base64url')},
    ContentService: {MimeType: {JSON: 'application/json'}, createTextOutput: text => ({setMimeType: () => JSON.parse(text)})},
  });
  vm.runInContext(readFileSync(new URL('../server/google-sheets/Code.gs', import.meta.url), 'utf8'), runtime);
  return {runtime, state, properties, sheets, post: body => runtime.doPost({postData: {contents: JSON.stringify(body)}}), get: action => runtime.doGet({parameter: {action}})};
}

function test() {
  const {runtime, state, properties, sheets, get, post} = createSandbox();
  assert(get('brick_leaderboard').error, 'Unconfigured game must fail instead of returning SOLLERS scores');
  const sheetId = runtime.setupBrickBazukaLeaderboard();
  assert.equal(runtime.setupBrickBazukaLeaderboard(), sheetId, 'Setup is idempotent');
  assert.notEqual(sheetId, properties.get('SPREADSHEET_ID'), 'Each game owns separate storage');
  const first = post({action: 'brick_runs'}), second = post({action: 'brick_runs'});
  assert.notEqual(first.id, second.id);
  assert.equal(first.game, 'brick-bazuka');
  const score = {...first, action: 'brick_scores', name: 'Игрок А', score: 120};
  assert.equal(post(score).rank, 1);
  assert.equal(post({...second, action: 'brick_scores', name: 'Игрок Б', score: 240}).rank, 1);
  assert.equal(post(score).rank, 2);
  assert.equal(sheets.get(sheetId).rows.length, 2, 'Retry does not duplicate a record');
  assert(post({...score, score: 121}).error, 'An accepted run is immutable');
  assert.equal(get('brick_leaderboard').rows[0].name, 'Игрок Б');
  assert.equal(get('leaderboard').rows.length, 0, 'BRICK never writes to the SOLLERS board');
  const third = post({action: 'brick_runs'});
  for (const name of ['=IMPORTXML(1)', '+cmd', '@cmd', '-cmd', "'hidden", '<script>', 'A', 'A\nB', 'A\u202eB', 'А'.repeat(21)]) {
    assert(post({...third, action: 'brick_scores', name, score: 10}).error, `Reject unsafe name: ${JSON.stringify(name)}`);
  }
  for (const value of [-1, 1.5, '100', true, 999999]) assert(post({...third, action: 'brick_scores', name: 'Игрок В', score: value}).error);
  assert(post({...third, action: 'brick_scores', token: third.token + 'x', name: 'Игрок В', score: 10}).error);
  const sollers = post({action: 'runs'});
  assert(post({...sollers, action: 'brick_scores', name: 'Игрок', score: 10}).error, 'Cross-game tokens are rejected');
  assert(post({...third, action: 'scores', name: 'Игрок', score: 10, distance: 0}).error);
  assert.equal(post({...sollers, action: 'scores', name: 'Пилот', score: 10, distance: 0}).saved, true);
  assert.equal(get('leaderboard').rows.length, 1);
  assert.equal(get('brick_leaderboard').rows.length, 2);
  for (let i = 0; i < 11; i++) post({...post({action: 'brick_runs'}), action: 'brick_scores', name: `Игрок ${i}`, score: 300 + i});
  const leaders = get('brick_leaderboard');
  assert.equal(leaders.rows.length, 10);
  assert.equal(leaders.rows[0].score, 310);
  assert(!JSON.stringify(leaders).includes(first.id));
  assert(!JSON.stringify(leaders).includes(first.token));
  assert.equal(post({...third, action: 'brick_scores', name: '  Игрок В  ', score: 0}).saved, true);
  state.busy = true;
  assert(post({action: 'brick_runs'}).error);
  state.busy = false;
  assert(runtime.doPost({postData: {contents: '['}}).error);
  console.log('LEADERBOARD_TEST_OK shared_scores separate_games idempotency signatures validation private_tokens top10');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) test();
