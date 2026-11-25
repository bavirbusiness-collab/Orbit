'use strict';
// Орбита: сервер этапа 2. Без внешних зависимостей: Node 22 (http, node:sqlite).
// REST + SSE (реальное время). Запуск: node server.js
const http = require('node:http');
const crypto = require('node:crypto');
const { DatabaseSync } = require('node:sqlite');

const PORT = Number(process.env.PORT || 8080);
const DEV = process.env.NODE_ENV !== 'production'; // в dev код входа возвращается в ответе
const db = new DatabaseSync(process.env.DB || 'orbita.db');
db.exec(`
PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, phone TEXT UNIQUE NOT NULL, name TEXT NOT NULL DEFAULT '', bio TEXT DEFAULT '', created INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS codes(phone TEXT PRIMARY KEY, code TEXT NOT NULL, expires INTEGER NOT NULL, tries INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS sessions(id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), token_hash TEXT UNIQUE NOT NULL, device TEXT, created INTEGER NOT NULL, last_seen INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS chats(id INTEGER PRIMARY KEY, type TEXT NOT NULL CHECK(type IN('direct','group')), title TEXT, owner_id INTEGER, expires INTEGER, created INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS members(chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE, user_id INTEGER NOT NULL REFERENCES users(id), role TEXT NOT NULL DEFAULT 'member', PRIMARY KEY(chat_id,user_id));
CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY, chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE, sender_id INTEGER NOT NULL, text TEXT NOT NULL, reply_to INTEGER, created INTEGER NOT NULL, edited INTEGER, deleted INTEGER NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS msg_chat ON messages(chat_id,id);
`);

const now = () => Date.now();
const sha = s => crypto.createHash('sha256').update(s).digest('hex');
class HttpError extends Error { constructor(s, m) { super(m); this.status = s; } }
const bad = (m, s = 400) => { throw new HttpError(s, m); };
const q = (sql, ...a) => db.prepare(sql).all(...a);
const one = (sql, ...a) => db.prepare(sql).get(...a);
const run = (sql, ...a) => db.prepare(sql).run(...a);

// ---- простые лимиты (в памяти) ----
const hits = new Map();
function limit(key, max, ms) {
  const t = now(), a = (hits.get(key) || []).filter(x => t - x < ms);
  if (a.length >= max) bad('Слишком много запросов, попробуйте позже', 429);
  a.push(t); hits.set(key, a);
}

// ---- SSE ----
const streams = new Map(); // userId -> Set(res)
function push(userIds, event, data) {
  const msg = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const u of userIds) for (const r of streams.get(u) || []) r.write(msg);
}
const memberIds = chatId => q('SELECT user_id FROM members WHERE chat_id=?', chatId).map(r => r.user_id);

// ---- модели ----
const pubUser = u => u && { id: u.id, phone: u.phone, name: u.name, bio: u.bio };
const msgOut = m => ({ id: m.id, chatId: m.chat_id, senderId: m.sender_id, senderName: (one('SELECT name FROM users WHERE id=?', m.sender_id) || {}).name || '', text: m.deleted ? null : m.text, replyTo: m.reply_to, created: m.created, edited: m.edited, deleted: !!m.deleted });
function needMember(chatId, uid) {
  const c = one('SELECT * FROM chats WHERE id=?', chatId);
  if (!c || (c.expires && c.expires < now())) bad('Чат не найден', 404);
  const m = one('SELECT role FROM members WHERE chat_id=? AND user_id=?', chatId, uid);
  if (!m) bad('Нет доступа к чату', 403);
  return { chat: c, role: m.role };
}
function str(v, name, max, min = 0) {
  if (typeof v !== 'string') bad(`Поле ${name} должно быть строкой`);
  v = v.trim();
  if (v.length < min || v.length > max) bad(`Поле ${name}: от ${min} до ${max} символов`);
  return v;
}

// ---- маршруты ----
const routes = [];
const route = (method, path, auth, fn) => routes.push({ method, re: new RegExp('^' + path.replace(/:(\w+)/g, '(?<$1>[^/]+)') + '$'), auth, fn });

const normPhone = v => {
  const p = '+' + String(v ?? '').replace(/\D/g, '');
  if (!/^\+\d{8,15}$/.test(p)) bad('Некорректный номер телефона');
  return p;
};

route('POST', '/auth/request', false, ({ body, ip }) => {
  const phone = normPhone(body.phone);
  limit('code:' + ip, 10, 3600e3); limit('code:' + phone, 3, 600e3);
  const code = String(crypto.randomInt(0, 1e6)).padStart(6, '0');
  run('INSERT INTO codes(phone,code,expires,tries) VALUES(?,?,?,0) ON CONFLICT(phone) DO UPDATE SET code=excluded.code,expires=excluded.expires,tries=0', phone, sha(code), now() + 600e3);
  // Тестовый режим: код возвращается в ответе (SMS-провайдер ещё не подключён).
  // В проде (NODE_ENV=production без SMS_TEST_MODE) здесь должна быть отправка SMS.
  if (DEV) console.log(`[dev] код для ${phone}: ${code}`);
  return DEV ? { ok: true, devCode: code } : { ok: true };
});

route('POST', '/auth/verify', false, ({ body, ip }) => {
  const phone = normPhone(body.phone), code = str(String(body.code ?? ''), 'code', 6, 6);
  limit('verify:' + ip, 30, 3600e3);
  const c = one('SELECT * FROM codes WHERE phone=?', phone);
  if (!c || c.expires < now()) bad('Код недействителен или истёк', 401);
  if (c.tries >= 5) bad('Слишком много попыток, запросите новый код', 429);
  run('UPDATE codes SET tries=tries+1 WHERE phone=?', phone);
  if (c.code !== sha(code)) bad('Неверный код', 401);
  run('DELETE FROM codes WHERE phone=?', phone);
  let u = one('SELECT * FROM users WHERE phone=?', phone);
  if (!u) { run('INSERT INTO users(phone,name,created) VALUES(?,?,?)', phone, '', now()); u = one('SELECT * FROM users WHERE phone=?', phone); }
  const token = crypto.randomBytes(32).toString('hex');
  run('INSERT INTO sessions(user_id,token_hash,device,created,last_seen) VALUES(?,?,?,?,?)', u.id, sha(token), String(body.device || 'unknown').slice(0, 60), now(), now());
  return { token, user: pubUser(u), needsProfile: !u.name };
});

route('GET', '/me', true, ({ user }) => ({ user: pubUser(user) }));

route('PATCH', '/me', true, ({ user, body }) => {
  const name = body.name !== undefined ? str(body.name, 'name', 60, 1) : user.name;
  const bio = body.bio !== undefined ? str(body.bio, 'bio', 200) : user.bio;
  run('UPDATE users SET name=?,bio=? WHERE id=?', name, bio, user.id);
  return { user: pubUser(one('SELECT * FROM users WHERE id=?', user.id)) };
});

// Поиск как в WhatsApp: по номеру телефона (цифры) или по имени. Видны только пользователи с именем.
route('GET', '/users/search', true, ({ user, query }) => {
  const raw = str(query.q || '', 'q', 40, 2);
  const esc = x => x.replace(/[%_\\]/g, m => '\\' + m);
  const digits = raw.replace(/\D/g, '');
  const byPhone = digits.length >= 5 && /^[+\d\s()-]+$/.test(raw);
  const rows = byPhone
    ? q("SELECT * FROM users WHERE name<>'' AND id<>? AND phone LIKE ? ESCAPE '\\' LIMIT 20", user.id, '%' + esc(digits) + '%')
    : q("SELECT * FROM users WHERE name<>'' AND id<>? AND name LIKE ? ESCAPE '\\' LIMIT 20", user.id, '%' + esc(raw) + '%');
  return { users: rows.map(pubUser) };
});

route('GET', '/sessions', true, ({ user, sid }) =>
  ({ sessions: q('SELECT id,device,created,last_seen FROM sessions WHERE user_id=? ORDER BY last_seen DESC', user.id).map(s => ({ ...s, current: s.id === sid })) }));
route('DELETE', '/sessions/:id', true, ({ user, params }) => {
  const r = run('DELETE FROM sessions WHERE id=? AND user_id=?', Number(params.id), user.id);
  if (!r.changes) bad('Сеанс не найден', 404);
  return { ok: true };
});

route('POST', '/chats/direct', true, ({ user, body }) => {
  const other = Number(body.userId);
  if (!other || other === user.id || !one('SELECT id FROM users WHERE id=?', other)) bad('Пользователь не найден', 404);
  const ex = one(`SELECT c.id FROM chats c JOIN members a ON a.chat_id=c.id AND a.user_id=? JOIN members b ON b.chat_id=c.id AND b.user_id=? WHERE c.type='direct'`, user.id, other);
  if (ex) return { chatId: ex.id, existed: true };
  const id = run('INSERT INTO chats(type,created) VALUES(?,?)', 'direct', now()).lastInsertRowid;
  run('INSERT INTO members VALUES(?,?,?)', id, user.id, 'member'); run('INSERT INTO members VALUES(?,?,?)', id, other, 'member');
  push([other], 'chat', { chatId: Number(id) });
  return { chatId: Number(id), existed: false };
});

route('POST', '/chats/group', true, ({ user, body }) => {
  const title = str(body.title, 'title', 80, 1);
  const ids = [...new Set((Array.isArray(body.members) ? body.members : []).map(Number))].filter(x => x && x !== user.id);
  if (ids.length > 199) bad('Не более 200 участников');
  for (const i of ids) if (!one('SELECT id FROM users WHERE id=?', i)) bad('Участник не найден: ' + i, 404);
  let expires = null;
  if (body.ttlDays !== undefined) { const d = Number(body.ttlDays); if (![1, 7, 30].includes(d)) bad('ttlDays: 1, 7 или 30'); expires = now() + d * 864e5; }
  const id = Number(run('INSERT INTO chats(type,title,owner_id,expires,created) VALUES(?,?,?,?,?)', 'group', title, user.id, expires, now()).lastInsertRowid);
  run('INSERT INTO members VALUES(?,?,?)', id, user.id, 'owner');
  for (const i of ids) run('INSERT INTO members VALUES(?,?,?)', id, i, 'member');
  push(ids, 'chat', { chatId: id });
  return { chatId: id, expires };
});

route('POST', '/chats/:id/members', true, ({ user, params, body }) => {
  const id = Number(params.id), { chat, role } = needMember(id, user.id);
  if (chat.type !== 'group') bad('Только для групп');
  if (!['owner', 'admin'].includes(role)) bad('Недостаточно прав', 403);
  const uid = Number(body.userId);
  if (!one('SELECT id FROM users WHERE id=?', uid)) bad('Пользователь не найден', 404);
  run('INSERT OR IGNORE INTO members VALUES(?,?,?)', id, uid, 'member');
  push([uid], 'chat', { chatId: id });
  return { ok: true };
});

route('GET', '/chats', true, ({ user }) => {
  const rows = q(`SELECT c.*, (SELECT id FROM messages m WHERE m.chat_id=c.id ORDER BY id DESC LIMIT 1) AS last_id FROM chats c JOIN members mm ON mm.chat_id=c.id AND mm.user_id=? WHERE c.expires IS NULL OR c.expires>?`, user.id, now());
  const chats = rows.map(c => {
    const peer = c.type === 'direct' ? one('SELECT u.* FROM members m JOIN users u ON u.id=m.user_id WHERE m.chat_id=? AND m.user_id<>?', c.id, user.id) : null;
    const last = c.last_id ? msgOut(one('SELECT * FROM messages WHERE id=?', c.last_id)) : null;
    return { id: c.id, type: c.type, title: peer ? peer.name : c.title, peer: pubUser(peer), expires: c.expires, last };
  }).sort((a, b) => (b.last?.created || 0) - (a.last?.created || 0));
  return { chats };
});

route('GET', '/chats/:id/messages', true, ({ user, params, query }) => {
  const id = Number(params.id); needMember(id, user.id);
  const lim = Math.min(Number(query.limit) || 50, 100), before = Number(query.before) || 9e15;
  return { messages: q('SELECT * FROM messages WHERE chat_id=? AND id<? ORDER BY id DESC LIMIT ?', id, before, lim).reverse().map(msgOut) };
});

route('POST', '/chats/:id/messages', true, ({ user, params, body }) => {
  const id = Number(params.id); needMember(id, user.id);
  limit('msg:' + user.id, 60, 60e3);
  const text = str(body.text, 'text', 4000, 1);
  let reply = null;
  if (body.replyTo !== undefined) { reply = Number(body.replyTo); if (!one('SELECT id FROM messages WHERE id=? AND chat_id=?', reply, id)) bad('Сообщение для ответа не найдено', 404); }
  const mid = Number(run('INSERT INTO messages(chat_id,sender_id,text,reply_to,created) VALUES(?,?,?,?,?)', id, user.id, text, reply, now()).lastInsertRowid);
  const m = msgOut(one('SELECT * FROM messages WHERE id=?', mid));
  push(memberIds(id), 'message', m);
  return { message: m };
});

route('PATCH', '/messages/:id', true, ({ user, params, body }) => {
  const m = one('SELECT * FROM messages WHERE id=?', Number(params.id));
  if (!m || m.deleted) bad('Сообщение не найдено', 404);
  needMember(m.chat_id, user.id);
  if (m.sender_id !== user.id) bad('Редактировать можно только свои сообщения', 403);
  run('UPDATE messages SET text=?,edited=? WHERE id=?', str(body.text, 'text', 4000, 1), now(), m.id);
  const out = msgOut(one('SELECT * FROM messages WHERE id=?', m.id));
  push(memberIds(m.chat_id), 'message_edited', out);
  return { message: out };
});

route('DELETE', '/messages/:id', true, ({ user, params }) => {
  const m = one('SELECT * FROM messages WHERE id=?', Number(params.id));
  if (!m || m.deleted) bad('Сообщение не найдено', 404);
  const { role } = needMember(m.chat_id, user.id);
  if (m.sender_id !== user.id && !['owner', 'admin'].includes(role)) bad('Недостаточно прав', 403);
  run("UPDATE messages SET deleted=1,text='' WHERE id=?", m.id);
  push(memberIds(m.chat_id), 'message_deleted', { id: m.id, chatId: m.chat_id });
  return { ok: true };
});

route('GET', '/events', true, ({ user, res, req }) => {
  res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store', connection: 'keep-alive' });
  res.write('retry: 3000\n\n');
  const set = streams.get(user.id) || new Set(); streams.set(user.id, set); set.add(res);
  const ping = setInterval(() => res.write(': ping\n\n'), 25e3);
  req.on('close', () => { clearInterval(ping); set.delete(res); if (!set.size) streams.delete(user.id); });
  return null; // ответ остаётся открытым
});

// ---- ядро ----
const server = http.createServer(async (req, res) => {
  const send = (s, o) => { res.writeHead(s, { 'content-type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(o)); };
  try {
    const url = new URL(req.url, 'http://x');
    const ip = req.socket.remoteAddress;
    let body = {};
    if (['POST', 'PATCH', 'PUT'].includes(req.method)) {
      const chunks = []; let size = 0;
      for await (const c of req) { size += c.length; if (size > 65536) bad('Слишком большой запрос', 413); chunks.push(c); }
      if (size) { try { body = JSON.parse(Buffer.concat(chunks).toString()); } catch { bad('Некорректный JSON'); } }
      if (body === null || typeof body !== 'object' || Array.isArray(body)) bad('Ожидается JSON-объект');
    }
    for (const r of routes) {
      if (r.method !== req.method) continue;
      const m = r.re.exec(url.pathname); if (!m) continue;
      const ctx = { req, res, body, ip, params: m.groups || {}, query: Object.fromEntries(url.searchParams) };
      if (r.auth) {
        const t = (req.headers.authorization || '').replace(/^Bearer /, '') || ctx.query.token;
        const s = t && one('SELECT * FROM sessions WHERE token_hash=?', sha(t));
        if (!s) bad('Требуется вход', 401);
        run('UPDATE sessions SET last_seen=? WHERE id=?', now(), s.id);
        ctx.user = one('SELECT * FROM users WHERE id=?', s.user_id); ctx.sid = s.id;
      }
      const out = r.fn(ctx);
      if (out !== null) send(200, out);
      return;
    }
    bad('Не найдено', 404);
  } catch (e) {
    if (e instanceof HttpError) return send(e.status, { error: e.message });
    console.error(e); send(500, { error: 'Внутренняя ошибка' });
  }
});

if (require.main === module) server.listen(PORT, () => console.log(`Орбита: сервер на :${PORT}${DEV ? ' (dev)' : ''}`));
module.exports = server;
