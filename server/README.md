# Орбита: сервер (этап 2, часть 1)
Node >= 22.5, без зависимостей. `npm test` проверка, `npm start` запуск (порт 8080, переменные PORT, DB, NODE_ENV=production).
В dev-режиме код входа возвращается в ответе и печатается в консоль; в production нужно подключить отправку e-mail (место: server.js, /auth/request).
API: /auth/request, /auth/verify, /me, /users/search, /sessions, /chats, /chats/direct, /chats/group, /chats/:id/members, /chats/:id/messages, /messages/:id, /events (SSE, токен в Authorization или ?token=).
