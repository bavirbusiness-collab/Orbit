import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'live.dart';

// Рабочие экраны: список чатов, переписка, новый чат, новая группа. Данные идут через сервер.

const _palette = [Color(0xFF3B4CCA), Color(0xFF0F8F7E), Color(0xFFC2410C), Color(0xFF7C3AED), Color(0xFF1B6FB3), Color(0xFF5A6280)];

Color _colorFor(int id) => _palette[id.abs() % _palette.length];

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).toList();
  if (parts.isEmpty) return '?';
  return parts.map((w) => w[0].toUpperCase()).join();
}

String _time(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final n = DateTime.now();
  if (d.year == n.year && d.month == n.month && d.day == n.day) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

class _Av extends StatelessWidget {
  final String name;
  final int id;
  final double size;
  const _Av(this.name, this.id, {this.size = 52});
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: size / 2,
        backgroundColor: _colorFor(id),
        child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      );
}

void _soon(BuildContext context, String what) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what скоро появится')));

// ---------- Закрытые разделы ----------

class ComingSoonPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String text;
  const ComingSoonPage({super.key, required this.title, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(radius: 44, backgroundColor: cs.surfaceContainerHighest, child: Icon(icon, size: 40, color: cs.onSurfaceVariant)),
              CircleAvatar(radius: 16, backgroundColor: cs.primary, child: Icon(Icons.lock, size: 16, color: cs.onPrimary)),
            ]),
            const SizedBox(height: 20),
            const Text('Скоро', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
          ]),
        ),
      ),
    );
  }
}

// ---------- Список чатов ----------

class LiveChatsPage extends StatefulWidget {
  const LiveChatsPage({super.key});
  @override
  State<LiveChatsPage> createState() => _LiveChatsPageState();
}

class _LiveChatsPageState extends State<LiveChatsPage> {
  String q = '';

  String preview(Chat c) {
    final m = c.last;
    if (m == null) return 'Нет сообщений';
    if (m.deleted) return 'Сообщение удалено';
    final mine = m.senderId == live.me?.id;
    final who = mine ? 'Вы: ' : (c.type == 'group' && m.senderName.isNotEmpty ? '${m.senderName}: ' : '');
    return '$who${m.text ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final needle = q.trim().toLowerCase();
        final list = [
          for (final c in live.chats)
            if (needle.isEmpty || c.title.toLowerCase().contains(needle) || preview(c).toLowerCase().contains(needle)) c,
        ];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Чаты', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                tooltip: 'Новый чат',
                onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LiveNewChatPage())),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: live.loadChats,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  hintText: 'Поиск по чатам',
                  leading: const Icon(Icons.search),
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) => setState(() => q = v),
                ),
              ),
              if (live.chats.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    const Text('Пока нет чатов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Нажмите «+» вверху и найдите друга по номеру телефона или имени.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                  ]),
                )
              else if (list.isEmpty)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Ничего не найдено'))),
              for (final c in list)
                ListTile(
                  leading: _Av(c.title, c.id),
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(preview(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (c.last != null) Text(_time(c.last!.created), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    if (live.pinned.contains(c.id)) Icon(Icons.push_pin, size: 14, color: cs.onSurfaceVariant),
                  ]),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => LiveConversationPage(chat: c))),
                  onLongPress: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ListTile(
                          leading: Icon(live.pinned.contains(c.id) ? Icons.push_pin_outlined : Icons.push_pin),
                          title: Text(live.pinned.contains(c.id) ? 'Открепить' : 'Закрепить'),
                          onTap: () {
                            Navigator.pop(ctx);
                            live.togglePin(c);
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ]),
          ),
        );
      },
    );
  }
}

// ---------- Переписка ----------

class LiveConversationPage extends StatefulWidget {
  final Chat chat;
  const LiveConversationPage({super.key, required this.chat});
  @override
  State<LiveConversationPage> createState() => _LiveConversationPageState();
}

class _LiveConversationPageState extends State<LiveConversationPage> {
  final draft = TextEditingController();
  final scroll = ScrollController();
  int? editingId;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    live.openChat(widget.chat);
  }

  @override
  void dispose() {
    live.closeChat();
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> send() async {
    final t = draft.text.trim();
    if (t.isEmpty) return;
    final edit = editingId;
    draft.clear();
    setState(() => editingId = null);
    await live.send(t, edit);
    if (!mounted) return;
    if (live.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(live.error!)));
    }
    _toBottom();
  }

  void actions(Msg m) {
    if (m.deleted) return;
    final mine = m.senderId == live.me?.id;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Копировать'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: m.text ?? ''));
              Navigator.pop(ctx);
            },
          ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Изменить'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  editingId = m.id;
                  draft.text = m.text ?? '';
                });
              },
            ),
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(ctx);
                live.deleteMsg(m);
              },
            ),
        ]),
      ),
    );
  }

  Widget bubble(BuildContext context, Msg m) {
    final cs = Theme.of(context).colorScheme;
    final mine = m.senderId == live.me?.id;
    final fg = mine ? cs.onPrimary : cs.onSurfaceVariant;
    final group = widget.chat.type == 'group';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => actions(m),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(color: mine ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (group && !mine && m.senderName.isNotEmpty)
              Text(m.senderName, style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            if (m.deleted)
              Text('Сообщение удалено', style: TextStyle(color: fg.withValues(alpha: 0.7), fontStyle: FontStyle.italic))
            else
              Text(m.text ?? '', style: TextStyle(color: fg)),
            Text('${m.edited ? 'изм. · ' : ''}${_time(m.created)}', style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chat = widget.chat;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          _Av(chat.title, chat.id, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (chat.type == 'group') const Text('группа', style: TextStyle(fontSize: 12)),
            ]),
          ),
        ]),
        actions: [
          IconButton(tooltip: 'Видеозвонок', icon: const Icon(Icons.videocam_outlined), onPressed: () => _soon(context, 'Видеозвонок')),
          IconButton(tooltip: 'Позвонить', icon: const Icon(Icons.call_outlined), onPressed: () => _soon(context, 'Звонок')),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListenableBuilder(
            listenable: live,
            builder: (context, _) {
              final msgs = live.messages;
              if (msgs.length != _shown) {
                _shown = msgs.length;
                _toBottom();
              }
              if (msgs.isEmpty) {
                return Center(child: Text('Сообщений пока нет. Напишите первым.', style: TextStyle(color: cs.onSurfaceVariant)));
              }
              return ListView(controller: scroll, padding: const EdgeInsets.all(12), children: [for (final m in msgs) bubble(context, m)]);
            },
          ),
        ),
        if (editingId != null)
          Container(
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Изменение сообщения')),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  editingId = null;
                  draft.clear();
                }),
              ),
            ]),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: draft,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Сообщение', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: draft.text.trim().isEmpty ? null : send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------- Новый чат ----------

class LiveNewChatPage extends StatefulWidget {
  const LiveNewChatPage({super.key});
  @override
  State<LiveNewChatPage> createState() => _LiveNewChatPageState();
}

class _LiveNewChatPageState extends State<LiveNewChatPage> {
  List<User> found = [];
  String q = '';
  bool searching = false;
  int _seq = 0;

  Future<void> search(String v) async {
    q = v;
    final my = ++_seq;
    if (v.trim().length < 2) {
      setState(() {
        found = [];
        searching = false;
      });
      return;
    }
    setState(() => searching = true);
    final r = await live.search(v);
    if (!mounted || my != _seq) return;
    setState(() {
      found = r;
      searching = false;
    });
  }

  Future<void> open(User u) async {
    final chat = await live.startDirect(u);
    if (!mounted) return;
    if (chat == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(live.error ?? 'Не удалось открыть чат')));
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => LiveConversationPage(chat: chat)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Новый чат')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(
            hintText: 'Номер телефона или имя',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            keyboardType: TextInputType.text,
            onChanged: search,
          ),
        ),
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.group_add_outlined)),
          title: const Text('Создать группу'),
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const LiveNewGroupPage())),
        ),
        ListTile(
          leading: CircleAvatar(backgroundColor: cs.surfaceContainerHighest, child: const Icon(Icons.campaign_outlined)),
          title: const Text('Создать канал'),
          trailing: const Icon(Icons.lock_outline, size: 18),
          onTap: () => _soon(context, 'Каналы'),
        ),
        ListTile(
          leading: CircleAvatar(backgroundColor: cs.surfaceContainerHighest, child: const Icon(Icons.public)),
          title: const Text('Создать орбиту'),
          trailing: const Icon(Icons.lock_outline, size: 18),
          onTap: () => _soon(context, 'Орбиты'),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('Люди в Orbit', style: TextStyle(fontWeight: FontWeight.w600))),
        if (searching) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (!searching && q.trim().length < 2)
          Padding(padding: const EdgeInsets.all(16), child: Text('Введите номер телефона (например +994 50 123 45 67) или имя друга.', style: TextStyle(color: cs.onSurfaceVariant))),
        if (!searching && q.trim().length >= 2 && found.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text('Никого не нашли. Друг должен сначала зарегистрироваться в Orbit.', style: TextStyle(color: cs.onSurfaceVariant))),
        for (final u in found)
          ListTile(
            leading: _Av(u.name, u.id, size: 44),
            title: Text(u.name),
            subtitle: Text(u.phone),
            onTap: () => open(u),
          ),
      ]),
    );
  }
}

// ---------- Новая группа ----------

class LiveNewGroupPage extends StatefulWidget {
  const LiveNewGroupPage({super.key});
  @override
  State<LiveNewGroupPage> createState() => _LiveNewGroupPageState();
}

class _LiveNewGroupPageState extends State<LiveNewGroupPage> {
  final title = TextEditingController();
  final picked = <User>[];
  List<User> found = [];
  int _seq = 0;
  bool creating = false;

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> search(String v) async {
    final my = ++_seq;
    final r = await live.search(v);
    if (!mounted || my != _seq) return;
    setState(() => found = r);
  }

  bool isPicked(User u) => picked.any((x) => x.id == u.id);

  Future<void> create() async {
    setState(() => creating = true);
    final chat = await live.createGroup(title.text, picked);
    if (!mounted) return;
    setState(() => creating = false);
    if (chat == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(live.error ?? 'Не удалось создать группу')));
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => LiveConversationPage(chat: chat)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ok = title.text.trim().isNotEmpty && picked.isNotEmpty && !creating;
    return Scaffold(
      appBar: AppBar(title: const Text('Новая группа')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: title,
          maxLength: 80,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Название группы', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        if (picked.isNotEmpty)
          Wrap(spacing: 8, children: [
            for (final u in picked) InputChip(label: Text(u.name), onDeleted: () => setState(() => picked.removeWhere((x) => x.id == u.id))),
          ]),
        const SizedBox(height: 8),
        SearchBar(
          hintText: 'Добавить по номеру или имени',
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          onChanged: search,
        ),
        for (final u in found)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            secondary: _Av(u.name, u.id, size: 44),
            title: Text(u.name),
            subtitle: Text(u.phone),
            value: isPicked(u),
            onChanged: (v) => setState(() {
              if (v == true) {
                if (!isPicked(u)) picked.add(u);
              } else {
                picked.removeWhere((x) => x.id == u.id);
              }
            }),
          ),
        if (found.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Найдите друзей и отметьте их.', style: TextStyle(color: cs.onSurfaceVariant))),
        const SizedBox(height: 16),
        FilledButton(onPressed: ok ? create : null, child: Padding(padding: const EdgeInsets.all(14), child: Text(creating ? 'Создаём…' : 'Создать группу (${picked.length})'))),
      ]),
    );
  }
}
