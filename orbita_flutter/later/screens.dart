import 'package:flutter/material.dart';
import 'api.dart';
import 'state.dart';

const _avatarColors = [Color(0xFF3B4CCA), Color(0xFF0F8F7E), Color(0xFFC2410C), Color(0xFF7C3AED), Color(0xFF5A6280)];

String hhmm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class Root extends StatelessWidget {
  final AppState st;
  const Root({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    switch (st.screen) {
      case Screen.login:
        return LoginScreen(st: st);
      case Screen.code:
        return CodeScreen(st: st);
      case Screen.profile:
        return ProfileScreen(st: st);
      case Screen.chats:
        return ChatsScreen(st: st);
      case Screen.newChat:
        return NewChatScreen(st: st);
      case Screen.chat:
        return ChatScreen(key: ValueKey(st.current?.id), st: st);
    }
  }
}

class ErrorLine extends StatelessWidget {
  final String? text;
  const ErrorLine(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    );
  }
}

class Avatar extends StatelessWidget {
  final String title;
  final double size;
  const Avatar(this.title, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[title.hashCode.abs() % _avatarColors.length];
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _Form extends StatelessWidget {
  final List<Widget> children;
  const _Form(this.children);
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
          ),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  final AppState st;
  const LoginScreen({super.key, required this.st});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final mail = TextEditingController(text: widget.st.email);
  late final base = TextEditingController(text: widget.st.api.base);
  @override
  void dispose() {
    mail.dispose();
    base.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    return _Form([
      const Text('Орбита', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
      const Text('Чаты, сообщества и видео в одном месте'),
      const SizedBox(height: 32),
      TextField(controller: mail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: base, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Адрес сервера', border: OutlineInputBorder())),
      ErrorLine(st.error),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: st.busy ? null : () => st.requestCode(base.text, mail.text),
        child: Padding(padding: const EdgeInsets.all(14), child: Text(st.busy ? 'Отправка…' : 'Получить код')),
      ),
    ]);
  }
}

class CodeScreen extends StatefulWidget {
  final AppState st;
  const CodeScreen({super.key, required this.st});
  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    return _Form([
      const Text('Введите код', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      Text('Код отправлен на ${st.email}'),
      if (st.devCode != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text('Тестовый режим, код: ${st.devCode}', style: TextStyle(color: Theme.of(context).colorScheme.primary))),
      const SizedBox(height: 24),
      TextField(controller: code, maxLength: 6, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '6 цифр', border: OutlineInputBorder())),
      ErrorLine(st.error),
      FilledButton(
        onPressed: st.busy ? null : () => st.verify(code.text),
        child: Padding(padding: const EdgeInsets.all(14), child: Text(st.busy ? 'Проверка…' : 'Войти')),
      ),
      TextButton(onPressed: () => st.go(Screen.login), child: const Text('Другой e-mail')),
    ]);
  }
}

class ProfileScreen extends StatefulWidget {
  final AppState st;
  const ProfileScreen({super.key, required this.st});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final name = TextEditingController(text: widget.st.me?.name ?? '');
  late final username = TextEditingController(text: widget.st.me?.username ?? '');
  @override
  void dispose() {
    name.dispose();
    username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    return _Form([
      const Text('Ваш профиль', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      const Text('Имя увидят другие, по @username вас смогут найти'),
      const SizedBox(height: 24),
      TextField(controller: name, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: username, decoration: const InputDecoration(labelText: '@username', helperText: 'Латиница, цифры и _, от 3 символов', border: OutlineInputBorder())),
      ErrorLine(st.error),
      FilledButton(
        onPressed: st.busy ? null : () => st.saveProfile(name.text, username.text),
        child: const Padding(padding: EdgeInsets.all(14), child: Text('Продолжить')),
      ),
    ]);
  }
}

class ChatsScreen extends StatelessWidget {
  final AppState st;
  const ChatsScreen({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [TextButton(onPressed: st.logout, child: const Text('Выйти'))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          st.found = [];
          st.go(Screen.newChat);
        },
        icon: const Icon(Icons.edit),
        label: const Text('Новый чат'),
      ),
      body: Column(children: [
        if (st.error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ErrorLine(st.error)),
        Expanded(
          child: st.chats.isEmpty
              ? Padding(padding: const EdgeInsets.all(20), child: Text('Чатов пока нет. Нажмите «Новый чат» и найдите человека по @username.', style: TextStyle(color: muted)))
              : ListView.builder(
                  itemCount: st.chats.length,
                  itemBuilder: (context, i) {
                    final c = st.chats[i];
                    final last = c.last;
                    final preview = last == null ? 'Нет сообщений' : (last.deleted ? 'Сообщение удалено' : (last.text ?? ''));
                    return ListTile(
                      leading: Avatar(c.title),
                      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: last == null ? null : Text(hhmm(last.created), style: TextStyle(fontSize: 12, color: muted)),
                      onTap: () => st.openChat(c),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class NewChatScreen extends StatelessWidget {
  final AppState st;
  const NewChatScreen({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый чат'), leading: BackButton(onPressed: () => st.go(Screen.chats))),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          const SizedBox(height: 8),
          TextField(
            autofocus: true,
            onChanged: st.search,
            decoration: const InputDecoration(labelText: 'Имя или @username', border: OutlineInputBorder()),
          ),
          ErrorLine(st.error),
          Expanded(
            child: ListView.builder(
              itemCount: st.found.length,
              itemBuilder: (context, i) {
                final u = st.found[i];
                return ListTile(
                  leading: Avatar(u.name),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('@${u.username ?? ''}'),
                  onTap: () => st.startDirect(u),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final AppState st;
  const ChatScreen({super.key, required this.st});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final draft = TextEditingController();
  final scroll = ScrollController();
  Msg? editing;
  int _shown = 0;

  @override
  void dispose() {
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _actions(Msg m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сообщение'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.st.deleteMsg(m);
            },
            child: const Text('Удалить'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                editing = m;
                draft.text = m.text ?? '';
              });
            },
            child: const Text('Изменить'),
          ),
        ],
      ),
    );
  }

  void _send() {
    final t = draft.text.trim();
    if (t.isEmpty) return;
    widget.st.send(t, editing?.id);
    draft.clear();
    setState(() => editing = null);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final cs = Theme.of(context).colorScheme;
    final chat = st.current;
    final myId = st.me?.id;
    if (st.messages.length != _shown) {
      _shown = st.messages.length;
      _toBottom();
    }
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => st.go(Screen.chats)),
        title: Row(children: [Avatar(chat?.title ?? '', size: 36), const SizedBox(width: 10), Flexible(child: Text(chat?.title ?? '', overflow: TextOverflow.ellipsis))]),
      ),
      body: Column(children: [
        if (st.error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ErrorLine(st.error)),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            itemCount: st.messages.length,
            itemBuilder: (context, i) {
              final m = st.messages[i];
              final mine = m.senderId == myId;
              final fg = mine ? cs.onPrimary : cs.onSurfaceVariant;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: GestureDetector(
                  onLongPress: mine && !m.deleted ? () => _actions(m) : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(color: mine ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      m.deleted
                          ? Text('Сообщение удалено', style: TextStyle(color: fg, fontStyle: FontStyle.italic))
                          : Text(m.text ?? '', style: TextStyle(color: fg)),
                      Text('${hhmm(m.created)}${m.edited && !m.deleted ? ' · изм.' : ''}', style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7))),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        if (editing != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text('Редактирование сообщения', style: TextStyle(color: cs.primary, fontSize: 13)))),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              Expanded(child: TextField(controller: draft, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Сообщение', border: OutlineInputBorder()))),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: _send, icon: Icon(editing != null ? Icons.check : Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
