import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'register.dart' show Session;

/// Адрес сервера по умолчанию. Можно изменить на экране ввода номера («Адрес сервера»).
const defaultServer = 'http://10.0.2.2:8080';

/// Живое состояние приложения: вход, чаты, сообщения. Работает через сервер.
class Live extends ChangeNotifier {
  SharedPreferences? _prefs;
  Api api = Api(defaultServer, null);
  User? me;
  String? devCode;
  List<Chat> chats = [];
  List<Msg> messages = [];
  Chat? current;
  Set<int> pinned = {};
  String? error;
  bool busy = false;
  bool _running = false;
  bool loggedOut = false;

  bool get loggedIn => api.token != null;
  String get server => api.base;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    api = Api(_prefs!.getString('base') ?? defaultServer, _prefs!.getString('token'));
    pinned = (_prefs!.getStringList('pinned') ?? const <String>[]).map(int.parse).toSet();
    if (loggedIn) _start();
  }

  void _set(void Function() f) {
    f();
    notifyListeners();
  }

  void _start() {
    _boot();
    if (_running) return;
    _running = true;
    _events();
  }

  Future<void> _boot() async {
    try {
      final j = await api.call('GET', '/me');
      _applyMe(User.fromJson(j['user'] as Map<String, dynamic>));
      await loadChats();
    } on ApiError catch (e) {
      _fail(e);
    }
    notifyListeners();
  }

  void _applyMe(User u) {
    me = u;
    Session.name = u.name;
    Session.phone = u.phone;
    Session.about = u.bio;
  }

  Future<void> _events() async {
    while (_running) {
      try {
        await api.listen(_onEvent);
      } catch (_) {}
      if (!_running) break;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  void _onEvent(String ev, String data) {
    try {
      final j = jsonDecode(data) as Map<String, dynamic>;
      switch (ev) {
        case 'message':
          _addMsg(Msg.fromJson(j));
          loadChats();
          break;
        case 'message_edited':
          final m = Msg.fromJson(j);
          _set(() => messages = [for (final x in messages) x.id == m.id ? m : x]);
          loadChats();
          break;
        case 'message_deleted':
          final id = j['id'] as int;
          _set(() => messages = [for (final x in messages) x.id == id ? x.asDeleted() : x]);
          loadChats();
          break;
        case 'chat':
          loadChats();
          break;
      }
    } catch (_) {}
  }

  void _addMsg(Msg m) {
    if (current?.id == m.chatId && !messages.any((x) => x.id == m.id)) {
      _set(() => messages = [...messages, m]);
    }
  }

  void _fail(ApiError e) {
    if (e.status == 401 && api.token != null) {
      logout();
    } else {
      error = e.message;
    }
  }

  // ---------- вход ----------

  Future<bool> requestCode(String phone) async {
    _set(() {
      busy = true;
      error = null;
    });
    var ok = false;
    try {
      final r = await api.call('POST', '/auth/request', {'phone': phone});
      devCode = r['devCode'] as String?;
      ok = true;
    } on ApiError catch (e) {
      error = e.message;
    }
    _set(() => busy = false);
    return ok;
  }

  /// Возвращает null при ошибке, иначе true, если нужно заполнить профиль.
  Future<bool?> verify(String phone, String code) async {
    _set(() {
      busy = true;
      error = null;
    });
    bool? needsProfile;
    try {
      final r = await api.call('POST', '/auth/verify', {'phone': phone, 'code': code.trim(), 'device': 'Orbit Android'});
      final token = r['token'] as String;
      api.token = token;
      await _prefs?.setString('token', token);
      _applyMe(User.fromJson(r['user'] as Map<String, dynamic>));
      loggedOut = false;
      needsProfile = r['needsProfile'] == true;
      _start();
    } on ApiError catch (e) {
      error = e.message;
    }
    _set(() => busy = false);
    return needsProfile;
  }

  Future<void> setServer(String url) async {
    final u = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (u.isEmpty) return;
    api = Api(u, api.token);
    await _prefs?.setString('base', u);
    notifyListeners();
  }

  Future<bool> saveProfile(String name, String bio) async {
    _set(() {
      busy = true;
      error = null;
    });
    var ok = false;
    try {
      final j = await api.call('PATCH', '/me', {'name': name.trim(), 'bio': bio.trim()});
      _applyMe(User.fromJson(j['user'] as Map<String, dynamic>));
      ok = true;
      await loadChats();
    } on ApiError catch (e) {
      _fail(e);
    }
    _set(() => busy = false);
    return ok;
  }

  void logout() {
    _running = false;
    api.stopListening();
    _prefs?.remove('token');
    api.token = null;
    me = null;
    chats = [];
    messages = [];
    current = null;
    loggedOut = true;
    notifyListeners();
  }

  // ---------- чаты ----------

  Future<void> loadChats() async {
    try {
      final j = await api.call('GET', '/chats');
      final list = [for (final c in j['chats'] as List) Chat.fromJson(c as Map<String, dynamic>)];
      list.sort((a, b) {
        final pa = pinned.contains(a.id) ? 0 : 1, pb = pinned.contains(b.id) ? 0 : 1;
        return pa != pb ? pa - pb : (b.last?.created ?? 0) - (a.last?.created ?? 0);
      });
      _set(() => chats = list);
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  Future<void> togglePin(Chat c) async {
    if (!pinned.add(c.id)) pinned.remove(c.id);
    await _prefs?.setStringList('pinned', [for (final x in pinned) '$x']);
    await loadChats();
  }

  Future<void> openChat(Chat chat) async {
    _set(() {
      error = null;
      current = chat;
      messages = [];
    });
    try {
      final j = await api.call('GET', '/chats/${chat.id}/messages?limit=100');
      _set(() => messages = [for (final m in j['messages'] as List) Msg.fromJson(m as Map<String, dynamic>)]);
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  void closeChat() {
    current = null;
    messages = [];
  }

  Future<void> send(String text, int? editingId) async {
    final chat = current;
    if (chat == null) return;
    error = null;
    try {
      if (editingId != null) {
        final j = await api.call('PATCH', '/messages/$editingId', {'text': text});
        final m = Msg.fromJson(j['message'] as Map<String, dynamic>);
        _set(() => messages = [for (final x in messages) x.id == m.id ? m : x]);
      } else {
        final j = await api.call('POST', '/chats/${chat.id}/messages', {'text': text});
        _addMsg(Msg.fromJson(j['message'] as Map<String, dynamic>));
      }
      loadChats();
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  Future<void> deleteMsg(Msg m) async {
    error = null;
    try {
      await api.call('DELETE', '/messages/${m.id}');
      _set(() => messages = [for (final x in messages) x.id == m.id ? x.asDeleted() : x]);
      loadChats();
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  Future<List<User>> search(String q) async {
    final s = q.trim();
    if (s.length < 2) return [];
    try {
      final j = await api.call('GET', '/users/search?q=${Uri.encodeQueryComponent(s)}');
      return [for (final u in j['users'] as List) User.fromJson(u as Map<String, dynamic>)];
    } on ApiError catch (e) {
      _set(() => _fail(e));
      return [];
    }
  }

  /// Создаёт (или находит) личный чат и возвращает его.
  Future<Chat?> startDirect(User u) async {
    try {
      final j = await api.call('POST', '/chats/direct', {'userId': u.id});
      final id = j['chatId'] as int;
      await loadChats();
      for (final c in chats) {
        if (c.id == id) return c;
      }
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
    return null;
  }

  Future<Chat?> createGroup(String title, List<User> members) async {
    try {
      final j = await api.call('POST', '/chats/group', {'title': title.trim(), 'members': [for (final u in members) u.id]});
      final id = j['chatId'] as int;
      await loadChats();
      for (final c in chats) {
        if (c.id == id) return c;
      }
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
    return null;
  }
}

final live = Live();
