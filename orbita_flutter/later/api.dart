import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiError implements Exception {
  final String message;
  final int status;
  ApiError(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class User {
  final int id;
  final String? username;
  final String name;
  final String bio;
  User(this.id, this.username, this.name, this.bio);
  factory User.fromJson(Map<String, dynamic> j) =>
      User(j['id'] as int, j['username'] as String?, (j['name'] ?? '') as String, (j['bio'] ?? '') as String);
}

class Msg {
  final int id;
  final int chatId;
  final int senderId;
  final String? text;
  final int? replyTo;
  final int created;
  final bool edited;
  final bool deleted;
  Msg(this.id, this.chatId, this.senderId, this.text, this.replyTo, this.created, this.edited, this.deleted);
  factory Msg.fromJson(Map<String, dynamic> j) => Msg(
        j['id'] as int,
        j['chatId'] as int,
        j['senderId'] as int,
        j['text'] as String?,
        j['replyTo'] as int?,
        j['created'] as int,
        j['edited'] != null,
        j['deleted'] == true,
      );
  Msg asDeleted() => Msg(id, chatId, senderId, null, replyTo, created, edited, true);
}

class Chat {
  final int id;
  final String type;
  final String title;
  final Msg? last;
  final int? expires;
  Chat(this.id, this.type, this.title, this.last, this.expires);
  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        j['id'] as int,
        j['type'] as String,
        (j['title'] ?? '') as String,
        j['last'] == null ? null : Msg.fromJson(j['last'] as Map<String, dynamic>),
        j['expires'] as int?,
      );
}

class Api {
  String base;
  String? token;
  http.Client? _sse;
  Api(this.base, this.token);

  Uri _uri(String path) => Uri.parse(base.trim().replaceAll(RegExp(r'/+$'), '') + path);
  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> call(String method, String path, [Map<String, dynamic>? body]) async {
    try {
      final req = http.Request(method, _uri(path))..headers.addAll(_headers);
      if (body != null) req.body = jsonEncode(body);
      final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 15)));
      Map<String, dynamic> j;
      try {
        j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        j = {};
      }
      if (res.statusCode < 200 || res.statusCode > 299) {
        throw ApiError((j['error'] ?? 'Ошибка ${res.statusCode}') as String, res.statusCode);
      }
      return j;
    } on ApiError {
      rethrow;
    } catch (_) {
      throw ApiError('Нет связи с сервером');
    }
  }

  /// Держит SSE-соединение, пока не оборвётся или не вызван stopListening().
  Future<void> listen(void Function(String, String) onEvent) async {
    final client = http.Client();
    _sse = client;
    try {
      final req = http.Request('GET', _uri('/events'))..headers.addAll(_headers);
      final res = await client.send(req);
      if (res.statusCode != 200) throw ApiError('Событийный канал: ${res.statusCode}', res.statusCode);
      var ev = 'message';
      await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('event:')) {
          ev = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          onEvent(ev, line.substring(5).trim());
          ev = 'message';
        }
      }
    } finally {
      client.close();
      if (identical(_sse, client)) _sse = null;
    }
  }

  void stopListening() {
    _sse?.close();
    _sse = null;
  }
}
