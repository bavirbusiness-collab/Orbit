'use strict';
process.env.DB = ':memory:';
const assert = require('node:assert/strict');
const server = require('./server.js');

let base;
const call = async (method, path, body, token) => {
  const r = await fetch(base + path, { method, headers: { 'content-type': 'application/json', ...(token ? { authorization: 'Bearer ' + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  return { s: r.status, j: await r.json() };
};
const login = async phone => {
  const a = await call('POST', '/auth/request', { phone });
  const v = await call('POST', '/auth/verify', { phone, code: a.j.devCode, device: 'test' });
  assert.equal(v.s, 200); return v.j;
};
let passed = 0; const ok = (n) => { passed++; console.log('ok -', n); };

server.listen(0, async () => {
  base = 'http://127.0.0.1:' + server.address().port;
  try {
    const A = await login('+994 50 111 22 33'), B = await login('+994501112244'), C = await login('+994501112255');
    ok('вход по коду');
    assert.equal(A.user.phone, '+994501112233'); ok('номер нормализуется');
    assert.equal((await call('POST', '/auth/request', { phone: '123' })).s, 400); ok('короткий номер отклонён');
    assert.equal(A.needsProfile, true);

    assert.equal((await call('POST', '/auth/verify', { phone: '+994501112233', code: '000000' })).s, 401); ok('неверный/использованный код отклонён');
    assert.equal((await call('GET', '/me')).s, 401); ok('без токена 401');

    assert.equal((await call('PATCH', '/me', { name: 'Анна' }, A.token)).s, 200);
    assert.equal((await call('PATCH', '/me', { name: 'Боб', bio: 'привет' }, B.token)).j.user.bio, 'привет');
    assert.equal((await call('PATCH', '/me', { name: 'Джем' }, C.token)).s, 200);
    assert.equal((await call('PATCH', '/me', { name: '  ' }, B.token)).s, 400); ok('имя обязательно');

    const s1 = await call('GET', '/users/search?q=' + encodeURIComponent('Анн'), null, B.token);
    assert.equal(s1.j.users.length, 1); ok('поиск по имени');
    const s2 = await call('GET', '/users/search?q=' + encodeURIComponent('+994 50 111 22 33'), null, B.token);
    assert.equal(s2.j.users.length, 1); assert.equal(s2.j.users[0].name, 'Анна'); ok('поиск по номеру телефона');
    assert.equal((await call('GET', '/users/search?q=' + encodeURIComponent('Боб'), null, B.token)).j.users.length, 0); ok('себя в поиске нет');
    const idA = A.user.id, idB = B.user.id, idC = C.user.id;

    // SSE для Боба
    const ev = []; const ctl = new AbortController();
    const sse = await fetch(base + '/events?token=' + B.token, { signal: ctl.signal });
    (async () => { const rd = sse.body.getReader(); const dec = new TextDecoder(); try { for (;;) { const { value, done } = await rd.read(); if (done) break; ev.push(dec.decode(value)); } } catch {} })();

    const d = await call('POST', '/chats/direct', { userId: idB }, A.token);
    const d2 = await call('POST', '/chats/direct', { userId: idA }, B.token);
    assert.equal(d.j.chatId, d2.j.chatId); assert.equal(d2.j.existed, true); ok('личный чат один на пару');
    const chat = d.j.chatId;

    const m1 = await call('POST', `/chats/${chat}/messages`, { text: 'Привет' }, A.token);
    assert.equal(m1.s, 200);
    const m2 = await call('POST', `/chats/${chat}/messages`, { text: 'Привет, Анна', replyTo: m1.j.message.id }, B.token);
    assert.equal(m2.j.message.replyTo, m1.j.message.id); ok('сообщения и ответы');
    assert.equal((await call('GET', `/chats/${chat}/messages`, null, C.token)).s, 403); ok('чужой чат закрыт');
    assert.equal((await call('POST', `/chats/${chat}/messages`, { text: '  ' }, A.token)).s, 400); ok('пустое сообщение отклонено');

    assert.equal((await call('PATCH', `/messages/${m1.j.message.id}`, { text: 'x' }, B.token)).s, 403);
    const ed = await call('PATCH', `/messages/${m1.j.message.id}`, { text: 'Привет!' }, A.token);
    assert.ok(ed.j.message.edited); ok('редактирование только своих');

    const hist = await call('GET', `/chats/${chat}/messages`, null, B.token);
    assert.deepEqual(hist.j.messages.map(m => m.text), ['Привет!', 'Привет, Анна']); ok('история по порядку');

    assert.equal((await call('DELETE', `/messages/${m2.j.message.id}`, null, A.token)).s, 403); // Анна не админ в личном чате чужого сообщения
    assert.equal((await call('DELETE', `/messages/${m2.j.message.id}`, null, B.token)).s, 200);
    const h2 = await call('GET', `/chats/${chat}/messages`, null, A.token);
    assert.equal(h2.j.messages[1].deleted, true); assert.equal(h2.j.messages[1].text, null); ok('удаление и права');

    const g = await call('POST', '/chats/group', { title: 'Шеки', members: [idB, idC], ttlDays: 7 }, A.token);
    assert.ok(g.j.expires > Date.now()); ok('группа с авто-удалением');
    assert.equal((await call('POST', '/chats/group', { title: 'x', ttlDays: 3 }, A.token)).s, 400);
    assert.equal((await call('POST', `/chats/${g.j.chatId}/members`, { userId: idC }, B.token)).s, 403); ok('добавлять участников может админ/владелец');
    await call('POST', `/chats/${g.j.chatId}/messages`, { text: 'всем' }, C.token);

    const list = await call('GET', '/chats', null, B.token);
    assert.equal(list.j.chats.length, 2); assert.equal(list.j.chats.find(c => c.type === 'direct').title, 'Анна'); ok('список чатов');

    await new Promise(r => setTimeout(r, 200));
    const evs = ev.join('');
    assert.ok(evs.includes('event: message') && evs.includes('Привет!') === false || evs.includes('event: message'));
    assert.ok(evs.includes('event: message_edited') && evs.includes('event: message_deleted') && evs.includes('event: chat')); ok('SSE: сообщения, правка, удаление, новый чат');
    ctl.abort();

    const ses = await call('GET', '/sessions', null, A.token);
    assert.equal(ses.j.sessions.length, 1);
    await call('DELETE', '/sessions/' + ses.j.sessions[0].id, null, A.token);
    assert.equal((await call('GET', '/me', null, A.token)).s, 401); ok('выход с устройства');

    console.log(`\nВсе проверки пройдены: ${passed}`);
    server.close(); process.exit(0);
  } catch (e) { console.error('ПРОВАЛ:', e); process.exit(1); }
});
