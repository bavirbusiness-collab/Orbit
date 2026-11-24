import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

enum Screen { login, code, profile, chats, newChat, chat }

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  Api api = Api('http://10.0.2.2:8080', null);
  Screen screen = Screen.login;
  bool ready = false;
  bool busy = false;
  String? error;
  String email = '';
  String? devCode;
  User? me;
  List<Chat> chats = [];
  List<Msg> messages = [];
  List<User> found = [];
  Chat? current;
  bool _running = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    api = Api(_prefs.getString('base') ?? 'http://10.0.2.2:8080', _prefs.getString('token'));
    if (api.token != null) {
      screen = Screen.chats;
      _start();
    }
    ready = true;
    notifyListeners();
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
      me = User.fromJson(j['user'] as Map<String, dynamic>);
      if (me!.username == null) screen = Screen.profile;
      await loadChats();
    } on ApiError catch (e) {
      _fail(e);
    }
    notifyListeners();
  }

  Future<void> _events() async {
    while (_running) {
      try {
        await api.listen(_onEvent);
      } catch (_) {}
      if (!_running) break;
      await Future.delayed(const Duration(seconds: 3));
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
    if (screen == Screen.chat && current?.id == m.chatId && !messages.any((x) => x.id == m.id)) {
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

  Future<void> loadChats() async {
    try {
      final j = await api.call('GET', '/chats');
      chats = [for (final c in j['chats'] as List) Chat.fromJson(c as Map<String, dynamic>)];
      notifyListeners();
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  Future<void> requestCode(String base, String mail) async {
    _set(() {
      busy = true;
      error = null;
    });
    try {
      api = Api(base.trim(), null);
      await _prefs.setString('base', base.trim());
      email = mail.trim();
      final r = await api.call('POST', '/auth/request', {'email': email});
      devCode = r['devCode'] as String?;
      screen = Screen.code;
    } on ApiError catch (e) {
      error = e.message;
    }
    _set(() => busy = false);
  }

  Future<void> verify(String code) async {
    _set(() {
      busy = true;
      error = null;
    });
    try {
      final r = await api.call('POST', '/auth/verify', {'email': email, 'code': code.trim(), 'device': 'Flutter'});
      final token = r['token'] as String;
      api.token = token;
      await _prefs.setString('token', token);
      me = User.fromJson(r['user'] as Map<String, dynamic>);
      screen = (r['needsProfile'] == true) ? Screen.profile : Screen.chats;
      _start();
    } on ApiError catch (e) {
      error = e.message;
    }
    _set(() => busy = false);
  }

  Future<void> saveProfile(String name, String username) async {
    _set(() {
      busy = true;
      error = null;
    });
    try {
      final j = await api.call('PATCH', '/me', {'name': name.trim(), 'username': username.trim()});
      me = User.fromJson(j['user'] as Map<String, dynamic>);
      screen = Screen.chats;
      await loadChats();
    } on ApiError catch (e) {
      _fail(e);
    }
    _set(() => busy = false);
  }

  Future<void> openChat(Chat chat) async {
    _set(() {
      error = null;
      current = chat;
      messages = [];
      screen = Screen.chat;
    });
    try {
      final j = await api.call('GET', '/chats/${chat.id}/messages?limit=100');
      _set(() => messages = [for (final m in j['messages'] as List) Msg.fromJson(m as Map<String, dynamic>)]);
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  Future<void> send(String text, int? editingId) async {
    final chat = current;
    if (chat == null) return;
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
    try {
      await api.call('DELETE', '/messages/${m.id}');
      _set(() => messages = [for (final x in messages) x.id == m.id ? x.asDeleted() : x]);
      loadChats();
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  Future<void> search(String q) async {
    final s = q.trim();
    if (s.length < 2) {
      _set(() => found = []);
      return;
    }
    try {
      final j = await api.call('GET', '/users/search?q=${Uri.encodeQueryComponent(s)}');
      final list = [for (final u in j['users'] as List) User.fromJson(u as Map<String, dynamic>)];
      _set(() => found = list.where((u) => u.id != me?.id).toList());
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  Future<void> startDirect(User u) async {
    try {
      final j = await api.call('POST', '/chats/direct', {'userId': u.id});
      final id = j['chatId'] as int;
      await loadChats();
      final matches = chats.where((c) => c.id == id);
      if (matches.isNotEmpty) {
        await openChat(matches.first);
      } else {
        _set(() => screen = Screen.chats);
      }
    } on ApiError catch (e) {
      _set(() => _fail(e));
    }
  }

  void go(Screen s) => _set(() {
        error = null;
        screen = s;
      });

  void back() {
    if (screen == Screen.code) {
      go(Screen.login);
    } else {
      go(Screen.chats);
    }
  }

  void logout() {
    _running = false;
    api.stopListening();
    _prefs.remove('token');
    api.token = null;
    me = null;
    chats = [];
    messages = [];
    error = null;
    screen = Screen.login;
    notifyListeners();
  }
}
