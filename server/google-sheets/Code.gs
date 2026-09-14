/* SOLLERS Traffic Rush: private storage, public score API. */
var LIMIT = 50;
var HEADERS = ['Позывной', 'Очки', 'Дистанция, м', 'Дата', 'ID заезда'];

function setupLeaderboard() {
  var properties = PropertiesService.getScriptProperties();
  if (!properties.getProperty('SIGNING_KEY')) properties.setProperty('SIGNING_KEY', Utilities.getUuid() + Utilities.getUuid());
  var id = properties.getProperty('SPREADSHEET_ID');
  if (!id) {
    var spreadsheet = SpreadsheetApp.create('SOLLERS Traffic Rush — результаты');
    properties.setProperty('SPREADSHEET_ID', spreadsheet.getId());
    var sheet = spreadsheet.getSheets()[0];
    sheet.setName('Результаты');
    sheet.getRange(1, 1, 1, 5).setValues([HEADERS]).setFontWeight('bold').setBackground('#17242e').setFontColor('#ffffff');
    sheet.setFrozenRows(1);
    sheet.setColumnWidth(1, 210);
    sheet.setColumnWidths(2, 2, 135);
    sheet.setColumnWidth(4, 180);
    sheet.setColumnWidth(5, 300);
    sheet.getRange('B:C').setNumberFormat('0');
    sheet.getRange('D:D').setNumberFormat('yyyy-mm-dd hh:mm:ss');
    SpreadsheetApp.flush();
    id = spreadsheet.getId();
  }
  console.log('https://docs.google.com/spreadsheets/d/' + id + '/edit');
  return id;
}

function scoreSheet_() {
  var id = PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID');
  if (!id) throw new Error('Таблица результатов пока не подключена.');
  return SpreadsheetApp.openById(id).getSheetByName('Результаты');
}

function output_(data) {
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON);
}

function signature_(id, startedAt) {
  var key = PropertiesService.getScriptProperties().getProperty('SIGNING_KEY');
  if (!key) throw new Error('Таблица результатов пока не подключена.');
  return Utilities.base64EncodeWebSafe(Utilities.computeHmacSha256Signature(id + '.' + startedAt, key)).replace(/=+$/, '');
}

function sameSignature_(a, b) {
  if (typeof a !== 'string' || a.length !== b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function newRun_() {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) throw new Error('Сервер занят. Попробуйте ещё раз.');
  try {
    var cache = CacheService.getScriptCache();
    var bucket = 'starts:' + Math.floor(Date.now() / 60000);
    var count = Number(cache.get(bucket) || 0);
    if (count >= 300) throw new Error('Много новых заездов. Попробуйте через минуту.');
    cache.put(bucket, String(count + 1), 120);
  } finally { lock.releaseLock(); }
  var id = Utilities.getUuid(), now = Date.now();
  return {id: id, token: now + '.' + signature_(id, now)};
}

function validateScore_(body, now) {
  if (typeof body.id !== 'string' || !/^[a-f0-9-]{36}$/i.test(body.id) || typeof body.token !== 'string') throw new Error('Заезд не найден. Начните новый заезд.');
  var token = body.token.split('.');
  var startedAt = Number(token[0]);
  if (token.length !== 2 || !Number.isSafeInteger(startedAt) || startedAt > now || now - startedAt > 86400000 || !sameSignature_(token[1], signature_(body.id, startedAt))) throw new Error('Срок заезда истёк. Начните новый заезд.');
  var seconds = (now - startedAt) / 1000;
  var name = String(body.name || '').trim();
  if (name.length < 2 || name.length > 20 || /^[=+@\-]/.test(name) || /[<>\x00-\x1f]/.test(name)) throw new Error('Позывной: 2–20 символов, без служебных знаков в начале.');
  if (!Number.isInteger(body.score) || body.score < 0 || body.score > seconds * 18 + 30 || !Number.isInteger(body.distance) || body.distance < 0 || body.distance > seconds * 70 + 20) throw new Error('Не удалось подтвердить результат заезда.');
  return name;
}

function saveScore_(body) {
  var now = Date.now(), name = validateScore_(body, now);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) throw new Error('Таблица занята. Повторите сохранение.');
  try {
    var sheet = scoreSheet_();
    var previous = sheet.getLastRow() > 1 ? sheet.getRange(2, 5, sheet.getLastRow() - 1, 1).createTextFinder(body.id).matchEntireCell(true).findNext() : null;
    if (previous) {
      var existing = sheet.getRange(previous.getRow(), 1, 1, 3).getValues()[0];
      if (existing[0] !== name || existing[1] !== body.score || existing[2] !== body.distance) throw new Error('Этот заезд уже сохранён.');
      return {saved: true};
    }
    sheet.appendRow([name, body.score, body.distance, new Date(now), body.id]);
    SpreadsheetApp.flush();
    CacheService.getScriptCache().remove('leaderboard');
    return {saved: true};
  } finally { lock.releaseLock(); }
}

function leaderboard_() {
  var cache = CacheService.getScriptCache(), cached = cache.get('leaderboard');
  if (cached) return JSON.parse(cached);
  var sheet = scoreSheet_();
  var data = sheet.getLastRow() > 1 ? sheet.getRange(2, 1, sheet.getLastRow() - 1, 4).getValues() : [];
  data = data.filter(function(row) { return typeof row[0] === 'string' && Number.isFinite(row[1]) && Number.isFinite(row[2]); });
  data.sort(function(a, b) { return b[1] - a[1] || new Date(a[3]).getTime() - new Date(b[3]).getTime(); });
  var result = {rows: data.slice(0, LIMIT).map(function(row, i) { return {rank: i + 1, name: row[0], score: row[1], distance: row[2]}; }), updatedAt: new Date().toISOString()};
  cache.put('leaderboard', JSON.stringify(result), 10);
  return result;
}

function doGet(e) {
  try {
    var action = e && e.parameter && e.parameter.action;
    if (action === 'brick_leaderboard') return output_(brickLeaderboard_());
    if (action === 'config') return output_({socialUrl: null, socialLabel: 'СОЦСЕТИ ДИЛЕРА', phoneReady: false, privacyUrl: null, continueMode: 'alternate'});
    if (action === 'leaderboard') return output_(leaderboard_());
    return output_({service: 'SOLLERS Traffic Rush', ready: Boolean(PropertiesService.getScriptProperties().getProperty('SPREADSHEET_ID'))});
  } catch (error) { return output_({error: error.message || 'Сервер результатов недоступен.'}); }
}

function doPost(e) {
  try {
    var raw = e && e.postData && e.postData.contents;
    if (typeof raw !== 'string' || raw.length > 4096) throw new Error('Некорректный запрос.');
    var body = JSON.parse(raw);
    if (!body || Array.isArray(body) || typeof body !== 'object') throw new Error('Некорректный запрос.');
    if (body.action === 'brick_runs') return output_(brickNewRun_());
    if (body.action === 'brick_scores') return output_(brickSaveScore_(body));
    if (body.action === 'runs') return output_(newRun_());
    if (body.action === 'scores') return output_(saveScore_(body));
    throw new Error('Действие недоступно.');
  } catch (error) { return output_({error: error.message || 'Не удалось сохранить результат.'}); }
}

// BRICK BAZUKA uses its own Sheet, cache and token namespace.
function setupBrickBazukaLeaderboard() {
  var properties = PropertiesService.getScriptProperties();
  if (!properties.getProperty('SIGNING_KEY')) properties.setProperty('SIGNING_KEY', Utilities.getUuid() + Utilities.getUuid());
  var id = properties.getProperty('BRICK_SPREADSHEET_ID');
  if (!id) {
    var spreadsheet = SpreadsheetApp.create('BRICK BAZUKA — рейтинг');
    id = spreadsheet.getId();
    var sheet = spreadsheet.getSheets()[0];
    sheet.setName('Результаты');
    sheet.getRange(1, 1, 1, 4).setValues([['Имя', 'Очки', 'Дата', 'ID забега']]).setFontWeight('bold').setBackground('#071f38').setFontColor('#ffffff');
    sheet.setFrozenRows(1);
    sheet.setColumnWidth(1, 210);
    sheet.setColumnWidth(2, 120);
    sheet.setColumnWidth(3, 180);
    sheet.setColumnWidth(4, 300);
    sheet.getRange('B:B').setNumberFormat('0');
    sheet.getRange('C:C').setNumberFormat('yyyy-mm-dd hh:mm:ss');
    SpreadsheetApp.flush();
    properties.setProperty('BRICK_SPREADSHEET_ID', id);
  }
  console.log('https://docs.google.com/spreadsheets/d/' + id + '/edit');
  return id;
}

function brickSheet_() {
  var id = PropertiesService.getScriptProperties().getProperty('BRICK_SPREADSHEET_ID');
  if (!id) throw new Error('Рейтинг BRICK BAZUKA пока не подключён.');
  return SpreadsheetApp.openById(id).getSheetByName('Результаты');
}

function brickSignature_(id, startedAt) {
  var key = PropertiesService.getScriptProperties().getProperty('SIGNING_KEY');
  if (!key) throw new Error('Рейтинг пока не подключён.');
  return Utilities.base64EncodeWebSafe(Utilities.computeHmacSha256Signature('brick-bazuka.' + id + '.' + startedAt, key)).replace(/=+$/, '');
}

function brickNewRun_() {
  brickSheet_();
  var run = newRun_(), startedAt = Number(run.token.split('.')[0]);
  return {game: 'brick-bazuka', id: run.id, token: startedAt + '.' + brickSignature_(run.id, startedAt)};
}

function brickValidate_(body, now) {
  if (typeof body.id !== 'string' || !/^[a-f0-9-]{36}$/i.test(body.id) || typeof body.token !== 'string') throw new Error('Забег не найден. Начните новый забег.');
  var token = body.token.split('.'), startedAt = Number(token[0]);
  if (token.length !== 2 || !Number.isSafeInteger(startedAt) || startedAt > now || now - startedAt > 86400000 || !sameSignature_(token[1], brickSignature_(body.id, startedAt))) throw new Error('Срок забега истёк. Начните новый забег.');
  if (typeof body.name !== 'string' || /[<>\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]/.test(body.name)) throw new Error('Имя: 2–20 символов без служебных знаков.');
  var name = body.name.trim().normalize('NFC');
  if (name.length < 2 || name.length > 20 || /^[=+@\-']/.test(name)) throw new Error('Имя: 2–20 символов без служебных знаков в начале.');
  // 730 px/s * 0.19 points/px, with a small network-start allowance.
  var seconds = (now - startedAt) / 1000;
  if (!Number.isSafeInteger(body.score) || body.score < 0 || body.score > 1000000 || body.score > (seconds + 15) * 145 + 50) throw new Error('Не удалось подтвердить очки этого забега.');
  return name;
}

function brickRows_() {
  var sheet = brickSheet_();
  var rows = sheet.getLastRow() > 1 ? sheet.getRange(2, 1, sheet.getLastRow() - 1, 4).getValues() : [];
  rows = rows.filter(function(row) { return typeof row[0] === 'string' && Number.isFinite(row[1]) && row[1] >= 0; });
  rows.sort(function(a, b) { return b[1] - a[1] || new Date(a[2]).getTime() - new Date(b[2]).getTime(); });
  return rows;
}

function brickSaveScore_(body) {
  var now = Date.now(), name = brickValidate_(body, now);
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) throw new Error('Таблица занята. Повторите сохранение.');
  try {
    var sheet = brickSheet_();
    var previous = sheet.getLastRow() > 1 ? sheet.getRange(2, 4, sheet.getLastRow() - 1, 1).createTextFinder(body.id).matchEntireCell(true).findNext() : null;
    if (previous) {
      var existing = sheet.getRange(previous.getRow(), 1, 1, 2).getValues()[0];
      if (existing[0] !== name || existing[1] !== body.score) throw new Error('Этот забег уже сохранён.');
    } else {
      sheet.appendRow([name, body.score, new Date(now), body.id]);
      SpreadsheetApp.flush();
      CacheService.getScriptCache().remove('brick:leaderboard');
    }
    var rows = brickRows_(), rank = rows.findIndex(function(row) { return row[3] === body.id; }) + 1;
    return {game: 'brick-bazuka', saved: true, rank: rank};
  } finally { lock.releaseLock(); }
}

function brickLeaderboard_() {
  var cache = CacheService.getScriptCache(), cached = cache.get('brick:leaderboard');
  if (cached) return JSON.parse(cached);
  var rows = brickRows_();
  var result = {game: 'brick-bazuka', rows: rows.slice(0, 10).map(function(row, index) { return {rank: index + 1, name: row[0], score: row[1]}; }), updatedAt: new Date().toISOString()};
  cache.put('brick:leaderboard', JSON.stringify(result), 10);
  return result;
}
