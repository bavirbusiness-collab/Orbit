import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding.dart';
import 'register.dart';

// Макет Orbit: все данные выдуманные, сервера нет. Реальная логика лежит в папке later/.

void main() => runApp(const OrbitaMock());

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

const seed = Color(0xFF3B4CCA);
const teal = Color(0xFF0F8F7E);
const rust = Color(0xFFC2410C);

class OrbitaMock extends StatelessWidget {
  const OrbitaMock({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
      themeMode: mode,
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const Gate(),
    ));
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [ChatsPage(), StatusPage(), OrbitsPage(), ProfilePage()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Чаты'),
          NavigationDestination(icon: Icon(Icons.data_usage), label: 'Статусы'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Орбиты'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const Avatar(this.text, this.color, {super.key, this.size = 52});
  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: size / 2,
        backgroundColor: color,
        child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      );
}

// ---------- Чаты ----------

class ChatItem {
  final String name, last, time, initials;
  final Color color;
  final int unread;
  final bool group;
  final List<String> members;
  final int? ttlDays;
  final bool channel;
  final bool mine;
  const ChatItem(this.name, this.last, this.time, this.initials, this.color, [this.unread = 0, this.group = false, this.members = const [], this.ttlDays, this.channel = false, this.mine = false]);
}

final chatsRevision = ValueNotifier<int>(0);

class Orbit {
  String name;
  Color color;
  List<String> items; // названия чатов, групп и каналов
  Orbit(this.name, this.color, this.items);
}

final orbits = <Orbit>[
  Orbit('Рыбалка', seed, ['Руслан', 'Клёв на Мингечевире']),
  Orbit('Учёба', teal, ['Группа 11-Б']),
  Orbit('Семья', rust, ['Мама']),
];
final chatQuery = ValueNotifier<String>('');
final orbitFilter = ValueNotifier<String?>(null); // выбранная орбита в списке чатов
final orbitsRevision = ValueNotifier<int>(0);

final chatItems = <ChatItem>[
  ChatItem('Руслан', 'Завтра на озеро в семь?', '11:42', 'Р', seed, 2),
  ChatItem('Группа 11-Б', 'Лейла: конспект уже в канале', '10:15', 'Г', teal, 0, true, ['Лейла', 'Рустам', 'Нигяр']),
  ChatItem('Поездка в Шеки', 'Комната закроется через 6 дней', 'вчера', 'Ш', rust, 0, true, ['Нигяр', 'Эльчин'], 7),
  ChatItem('Клёв на Мингечевире', 'Свежий отчёт: утром берёт на мормышку', '09:05', 'К', Color(0xFF1B6FB3), 0, false, [], null, true),
  ChatItem('Мама', 'Видео-ответ · 0:14', 'вчера', 'М', Color(0xFF5A6280)),
];

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});
  static final searchCtl = TextEditingController();

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<int>(valueListenable: chatsRevision, builder: (context, _, __) => _page(context));

  Widget _page(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NewChatPage())), icon: const Icon(Icons.add_circle_outline))],
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(
            hintText: 'Поиск людей, чатов, видео',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            controller: searchCtl,
            trailing: [
              if (chatQuery.value.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    searchCtl.clear();
                    chatQuery.value = '';
                    chatsRevision.value++;
                  },
                ),
            ],
            onChanged: (v) {
              chatQuery.value = v;
              chatsRevision.value++;
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('Все'),
              selected: orbitFilter.value == null,
              onSelected: (_) {
                orbitFilter.value = null;
                chatsRevision.value++;
              },
            ),
            for (final o in orbits)
              ChoiceChip(
                label: Text(o.name),
                selected: orbitFilter.value == o.name,
                onSelected: (_) {
                  orbitFilter.value = o.name;
                  chatsRevision.value++;
                },
              ),
          ]),
        ),
        for (final c in chatItems.where((c) =>
            (orbitFilter.value == null || orbits.any((o) => o.name == orbitFilter.value && o.items.contains(c.name))) &&
            (chatQuery.value.trim().isEmpty ||
                c.name.toLowerCase().contains(chatQuery.value.trim().toLowerCase()) ||
                c.last.toLowerCase().contains(chatQuery.value.trim().toLowerCase()))))
          ListTile(
            leading: Avatar(c.initials, c.color),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.last, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(c.time, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              if (c.unread > 0) Badge(label: Text('${c.unread}')),
            ]),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => c.channel ? ChannelPage(item: c) : ConversationPage(item: c))),
          ),
        if (chatItems.where((c) => (orbitFilter.value == null || orbits.any((o) => o.name == orbitFilter.value && o.items.contains(c.name))) && (chatQuery.value.trim().isEmpty || c.name.toLowerCase().contains(chatQuery.value.trim().toLowerCase()) || c.last.toLowerCase().contains(chatQuery.value.trim().toLowerCase()))).isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Ничего не найдено'))),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Дайджест тишины', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('Пока вы были в режиме «Тишина»: 14 сообщений в 3 чатах.'),
          ]),
        ),
      ]),
    );
  }
}

class ConversationPage extends StatefulWidget {
  final ChatItem item;
  const ConversationPage({super.key, required this.item});
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _Bubble {
  final String text;
  final bool mine;
  final String time;
  final String? sub;
  String? reaction;
  _Bubble(this.text, this.mine, this.time, {this.sub});
}

class _ConversationPageState extends State<ConversationPage> {
  final draft = TextEditingController();
  final scroll = ScrollController();
  late final List<_Bubble> items;

  @override
  void initState() {
    super.initState();
    // Старые сообщения показываем только в чате с Русланом, остальные чаты пустые.
    items = widget.item.name == 'Руслан'
        ? [
            _Bubble('Завтра на озеро в семь?', false, '11:40'),
            _Bubble('Давай в 6:40, пока клёв. Возьму термос.', true, '11:42'),
            _Bubble('Голос · 0:21\n«…возьми удочку побольше, там глубоко…»', false, '11:44', sub: 'Расшифровка на устройстве'),
          ]
        : [];
  }

  @override
  void dispose() {
    draft.dispose();
    scroll.dispose();
    super.dispose();
  }

  String _now() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void send() {
    final t = draft.text.trim();
    if (t.isEmpty) return;
    setState(() => items.add(_Bubble(t, true, _now())));
    draft.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Widget bubble(BuildContext context, _Bubble b) {
    final cs = Theme.of(context).colorScheme;
    final fg = b.mine ? cs.onPrimary : cs.onSurfaceVariant;
    return Align(
      alignment: b.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => pickReaction(b),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(color: b.mine ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(b.text, style: TextStyle(color: fg)),
            if (b.sub != null) Text(b.sub!, style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(b.time, style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 11)),
              if (b.reaction != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: fg.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text(b.reaction!, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  static const reactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  void pickReaction(_Bubble b) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final r in reactions)
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => b.reaction = b.reaction == r ? null : r);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: b.reaction == r ? BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle) : null,
                    child: Text(r, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: b.text));
                Navigator.pop(ctx);
              },
            ),
            if (b.reaction != null)
              ListTile(
                leading: const Icon(Icons.highlight_off),
                title: const Text('Убрать реакцию'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => b.reaction = null);
                },
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = widget.item;
    final hasText = draft.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: item.group ? () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => GroupInfoPage(item: item))) : null,
          child: Row(children: [
          Avatar(item.initials, item.color, size: 38),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(item.group ? '${item.members.length + 1} участников' : 'в сети', style: const TextStyle(fontSize: 12, color: teal)),
          ]),
        ]),
        ),
      ),
      body: Column(children: [
        if (item.name == 'Руслан')
          Container(
            width: double.infinity,
            color: cs.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text('Закреплено: Сбор у моста в 6:40', style: TextStyle(fontSize: 13)),
          ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text('Сообщений пока нет. Напишите первым.', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView(controller: scroll, padding: const EdgeInsets.all(14), children: [for (final b in items) bubble(context, b)]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file)),
              Expanded(
                child: TextField(
                  controller: draft,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Сообщение', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)))),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: hasText ? send : () {}, icon: Icon(hasText ? Icons.send : Icons.videocam_outlined)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------- Новый чат ----------

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});
  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  static const people = [
    ChatItem('Лейла', '', '', 'Л', teal),
    ChatItem('Рустам', '', '', 'Р', Color(0xFF7C3AED)),
    ChatItem('Нигяр', '', '', 'Н', rust),
    ChatItem('Эльчин', '', '', 'Э', Color(0xFF5A6280)),
  ];
  String q = '';

  @override
  Widget build(BuildContext context) {
    final list = [for (final p in people) if (p.name.toLowerCase().contains(q.trim().toLowerCase())) p];
    return Scaffold(
      appBar: AppBar(title: const Text('Новый чат')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(hintText: 'Имя или номер телефона', leading: const Icon(Icons.search), elevation: const WidgetStatePropertyAll(0), onChanged: (v) => setState(() => q = v)),
        ),
        ListTile(leading: const CircleAvatar(child: Icon(Icons.group_add_outlined)), title: const Text('Создать группу'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NewGroupPage()))),
        ListTile(leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)), title: const Text('Создать канал'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NewChannelPage()))),
        ListTile(leading: const CircleAvatar(child: Icon(Icons.public)), title: const Text('Создать орбиту'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NewOrbitPage()))),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('Друзья в Orbit', style: TextStyle(fontWeight: FontWeight.w600))),
        for (final p in list)
          ListTile(
            leading: Avatar(p.initials, p.color),
            title: Text(p.name),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => ConversationPage(item: p))),
          ),
        if (list.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Никого не нашли')),
      ]),
    );
  }
}

// ---------- Группы ----------

const demoPeople = [
  ChatItem('Лейла', '', '', 'Л', teal),
  ChatItem('Рустам', '', '', 'Р', Color(0xFF7C3AED)),
  ChatItem('Нигяр', '', '', 'Н', rust),
  ChatItem('Эльчин', '', '', 'Э', Color(0xFF5A6280)),
];

class NewGroupPage extends StatefulWidget {
  const NewGroupPage({super.key});
  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final name = TextEditingController();
  final picked = <String>{};
  int? ttl; // null = постоянная группа

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  bool get valid => name.text.trim().isNotEmpty && picked.isNotEmpty;

  void create() {
    final title = name.text.trim();
    final item = ChatItem(
      title,
      ttl == null ? 'Группа создана' : 'Комната закроется через $ttl дн.',
      'сейчас',
      title.substring(0, 1).toUpperCase(),
      seed,
      0,
      true,
      picked.toList(),
      ttl,
    );
    chatItems.insert(0, item);
    chatsRevision.value++;
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ConversationPage(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Новая группа')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: name,
          maxLength: 80,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Название группы', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        const Text('Срок жизни', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Временная комната удалится сама, например после поездки или события.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Постоянная'), selected: ttl == null, onSelected: (_) => setState(() => ttl = null)),
          for (final d in const [1, 7, 30])
            ChoiceChip(label: Text(d == 1 ? '1 день' : '$d дней'), selected: ttl == d, onSelected: (_) => setState(() => ttl = d)),
        ]),
        const SizedBox(height: 16),
        Text('Участники (${picked.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        for (final p in demoPeople)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Avatar(p.initials, p.color, size: 44),
            title: Text(p.name),
            value: picked.contains(p.name),
            onChanged: (v) => setState(() => v == true ? picked.add(p.name) : picked.remove(p.name)),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: valid ? create : null, child: const Padding(padding: EdgeInsets.all(14), child: Text('Создать группу'))),
      ]),
    );
  }
}

class GroupInfoPage extends StatelessWidget {
  final ChatItem item;
  const GroupInfoPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = {for (final p in demoPeople) p.name: p.color};
    return Scaffold(
      appBar: AppBar(title: const Text('О группе')),
      body: ListView(children: [
        const SizedBox(height: 16),
        Center(child: Avatar(item.initials, item.color, size: 88)),
        const SizedBox(height: 12),
        Center(child: Text(item.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        Center(child: Text('${item.members.length + 1} участников', style: TextStyle(color: cs.onSurfaceVariant))),
        if (item.ttlDays != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text('Временная комната: удалится через ${item.ttlDays} дн.')),
            ]),
          ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('Участники', style: TextStyle(fontWeight: FontWeight.w600))),
        ListTile(
          leading: const Avatar('ВЫ', seed, size: 44),
          title: const Text('Вы'),
          trailing: Text('владелец', style: TextStyle(color: cs.primary, fontSize: 13)),
        ),
        for (final m in item.members)
          ListTile(
            leading: Avatar(m.substring(0, 1), colors[m] ?? const Color(0xFF5A6280), size: 44),
            title: Text(m),
            trailing: Text('участник', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
        ListTile(leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1)), title: const Text('Добавить участника'), onTap: () {}),
        ListTile(leading: Icon(Icons.exit_to_app, color: cs.error), title: Text('Выйти из группы', style: TextStyle(color: cs.error)), onTap: () {}),
      ]),
    );
  }
}

// ---------- Каналы ----------

class ChannelInfo {
  final String description;
  final String link; // пусто у приватного канала
  final bool isPublic;
  int subscribers;
  ChannelInfo(this.description, this.link, this.isPublic, this.subscribers);
}

class Post {
  final String text, time;
  int views;
  Post(this.text, this.time, this.views);
}

final channelInfo = <String, ChannelInfo>{
  'Клёв на Мингечевире': ChannelInfo('Отчёты с воды, снасти и погода для рыбаков.', 'mingechevir_fish', true, 1240),
};

final channelPosts = <String, List<Post>>{
  'Клёв на Мингечевире': [
    Post('Свежий отчёт: утром берёт на мормышку, лучше у левого берега.', '09:05', 812),
    Post('Завтра ветер до 7 м/с, лодку лучше не брать.', 'вчера', 1104),
  ],
};

class NewChannelPage extends StatefulWidget {
  const NewChannelPage({super.key});
  @override
  State<NewChannelPage> createState() => _NewChannelPageState();
}

class _NewChannelPageState extends State<NewChannelPage> {
  final name = TextEditingController();
  final about = TextEditingController();
  final link = TextEditingController();
  bool isPublic = true;

  @override
  void dispose() {
    name.dispose();
    about.dispose();
    link.dispose();
    super.dispose();
  }

  bool get linkOk => !isPublic || RegExp(r'^[A-Za-z][A-Za-z0-9_]{2,31}$').hasMatch(link.text.trim());
  bool get valid => name.text.trim().isNotEmpty && linkOk;

  void create() {
    final title = name.text.trim();
    channelInfo[title] = ChannelInfo(about.text.trim(), isPublic ? link.text.trim() : 'join_${title.hashCode.abs()}', isPublic, 0);
    channelPosts[title] = [];
    final item = ChatItem(title, 'Канал создан', 'сейчас', title.substring(0, 1).toUpperCase(), const Color(0xFF1B6FB3), 0, false, const [], null, true, true);
    chatItems.insert(0, item);
    chatsRevision.value++;
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChannelPage(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Новый канал')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, maxLength: 80, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Название канала', border: OutlineInputBorder())),
        const SizedBox(height: 4),
        TextField(controller: about, maxLength: 200, maxLines: 3, decoration: const InputDecoration(labelText: 'Описание', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Публичный'), icon: Icon(Icons.public)),
            ButtonSegment(value: false, label: Text('Приватный'), icon: Icon(Icons.lock_outline)),
          ],
          selected: {isPublic},
          onSelectionChanged: (v) => setState(() => isPublic = v.first),
        ),
        const SizedBox(height: 12),
        if (isPublic) ...[
          TextField(
            controller: link,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Ссылка канала', prefixText: 'orbit.app/c/', border: OutlineInputBorder(), helperText: 'Латиница, цифры и _, от 3 символов'),
          ),
          const SizedBox(height: 4),
          Text('Публичный канал можно найти через поиск.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ] else
          Text('Приватный канал не виден в поиске. Попасть в него можно только по ссылке-приглашению, она создастся автоматически.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 20),
        FilledButton(onPressed: valid ? create : null, child: const Padding(padding: EdgeInsets.all(14), child: Text('Создать канал'))),
      ]),
    );
  }
}

class ChannelPage extends StatefulWidget {
  final ChatItem item;
  const ChannelPage({super.key, required this.item});
  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  final draft = TextEditingController();
  bool subscribed = false;

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  String _now() {
    final d = DateTime.now();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void publish() {
    final t = draft.text.trim();
    if (t.isEmpty) return;
    setState(() => channelPosts.putIfAbsent(widget.item.name, () => []).insert(0, Post(t, _now(), 0)));
    draft.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = widget.item;
    final info = channelInfo[item.name] ?? ChannelInfo('', '', true, 0);
    final posts = channelPosts[item.name] ?? [];
    final subs = info.subscribers + (subscribed ? 1 : 0);
    final linkText = info.isPublic ? 'orbit.app/c/${info.link}' : 'orbit.app/join/${info.link}';
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Avatar(item.initials, item.color, size: 38),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('$subs подписчиков', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (info.description.isNotEmpty) Text(info.description),
                if (info.description.isNotEmpty) const SizedBox(height: 8),
                Row(children: [
                  Icon(info.isPublic ? Icons.public : Icons.lock_outline, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(linkText, style: TextStyle(color: cs.primary))),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: linkText));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
                    },
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
            if (posts.isEmpty)
              Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(item.mine ? 'Публикаций пока нет. Напишите первую.' : 'Публикаций пока нет.', style: TextStyle(color: cs.onSurfaceVariant)))),
            for (final p in posts)
              Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.text, style: const TextStyle(fontSize: 15, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Icon(Icons.visibility_outlined, size: 15, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${p.views}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(width: 12),
                      Text(p.time, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
                  ]),
                ),
              ),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: item.mine
                ? Row(children: [
                    Expanded(child: TextField(controller: draft, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Новая публикация', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)))))),
                    const SizedBox(width: 6),
                    IconButton.filled(onPressed: publish, icon: const Icon(Icons.send)),
                  ])
                : SizedBox(
                    width: double.infinity,
                    child: subscribed
                        ? OutlinedButton(onPressed: () => setState(() => subscribed = false), child: const Padding(padding: EdgeInsets.all(12), child: Text('Вы подписаны · Отписаться')))
                        : FilledButton(onPressed: () => setState(() => subscribed = true), child: const Padding(padding: EdgeInsets.all(12), child: Text('Подписаться'))),
                  ),
          ),
        ),
      ]),
    );
  }
}

// ---------- Настройки ----------

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Макет: кроме темы, значения нигде не сохраняются.
  bool notify = true;
  bool sound = true;
  bool quiet = false;
  bool hideSubs = false;
  String lang = 'ru';
  String numberVisible = 'contacts';

  Widget section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(children: [
        section('Оформление'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: themeMode,
            builder: (context, mode, _) => SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Системная')),
                ButtonSegment(value: ThemeMode.light, label: Text('Светлая')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная')),
              ],
              selected: {mode},
              onSelectionChanged: (v) => themeMode.value = v.first,
            ),
          ),
        ),
        ListTile(
          title: const Text('Язык'),
          trailing: DropdownButton<String>(
            value: lang,
            underline: const SizedBox.shrink(),
            items: const [DropdownMenuItem(value: 'ru', child: Text('Русский')), DropdownMenuItem(value: 'az', child: Text('Azərbaycanca'))],
            onChanged: (v) => setState(() => lang = v ?? lang),
          ),
        ),
        section('Уведомления'),
        SwitchListTile(title: const Text('Уведомления о сообщениях'), value: notify, onChanged: (v) => setState(() => notify = v)),
        SwitchListTile(title: const Text('Звук'), value: sound, onChanged: (v) => setState(() => sound = v)),
        SwitchListTile(
          title: const Text('Режим «Тишина»'),
          subtitle: const Text('Вместо уведомлений вы получаете дайджест того, что пропустили'),
          value: quiet,
          onChanged: (v) => setState(() => quiet = v),
        ),
        section('Приватность'),
        ListTile(
          title: const Text('Кто видит мой номер'),
          trailing: DropdownButton<String>(
            value: numberVisible,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Все')),
              DropdownMenuItem(value: 'contacts', child: Text('Контакты')),
              DropdownMenuItem(value: 'nobody', child: Text('Никто')),
            ],
            onChanged: (v) => setState(() => numberVisible = v ?? numberVisible),
          ),
        ),
        SwitchListTile(title: const Text('Скрывать мои подписки'), value: hideSubs, onChanged: (v) => setState(() => hideSubs = v)),
        ListTile(leading: const Icon(Icons.block), title: const Text('Заблокированные'), subtitle: const Text('Никого нет'), onTap: () {}),
        section('Безопасность'),
        ListTile(
          leading: const Icon(Icons.devices),
          title: const Text('Активные сеансы'),
          subtitle: const Text('Этот телефон · сейчас'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Активные сеансы'),
              content: const Text('Этот телефон: сейчас в сети.\n\nЗавершить сеансы на других устройствах можно будет здесь.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
            ),
          ),
        ),
        section('Данные и память'),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Очистить кэш'),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Кэш очищен (в макете условно)'))),
        ),
        section('О приложении'),
        ListTile(title: const Text('Версия'), trailing: Text('0.0.1', style: TextStyle(color: cs.onSurfaceVariant))),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ---------- Статусы ----------

class StatusItem {
  final String name, initials, time;
  final Color color;
  final List<String> texts;
  final bool viewed;
  const StatusItem(this.name, this.initials, this.color, this.texts, this.time, {this.viewed = false});
}

const statuses = [
  StatusItem('Лейла', 'Л', teal, ['Утро на озере', 'Клёв начался'], 'сегодня, 08:15'),
  StatusItem('Рустам', 'Р', Color(0xFF7C3AED), ['Сдал экзамен'], 'сегодня, 07:40'),
  StatusItem('Нигяр', 'Н', rust, ['Шеки, день первый', 'Халва в Шеки лучшая'], 'вчера, 19:20', viewed: true),
];

class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  Widget ring(StatusItem st) {
    final c = st.viewed ? Colors.grey : seed;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 2.5)),
      child: Avatar(st.initials, st.color, size: 48),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recent = [for (final st in statuses) if (!st.viewed) st];
    final seen = [for (final st in statuses) if (st.viewed) st];
    void open(StatusItem st) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => StatusViewer(item: st)));
    return Scaffold(
      appBar: AppBar(title: const Text('Статусы', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(children: [
        ListTile(
          leading: Stack(children: [
            const Avatar('ВЫ', seed, size: 56),
            Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 10, backgroundColor: teal, child: const Icon(Icons.add, size: 14, color: Colors.white))),
          ]),
          title: const Text('Мой статус', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Нажмите, чтобы добавить'),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(leading: const Icon(Icons.text_fields), title: const Text('Текст'), onTap: () => Navigator.pop(ctx)),
                ListTile(leading: const Icon(Icons.photo_outlined), title: const Text('Фото'), onTap: () => Navigator.pop(ctx)),
                ListTile(leading: const Icon(Icons.videocam_outlined), title: const Text('Видео'), onTap: () => Navigator.pop(ctx)),
              ]),
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('Недавние', style: TextStyle(fontWeight: FontWeight.w600))),
        for (final st in recent) ListTile(leading: ring(st), title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(st.time), onTap: () => open(st)),
        if (seen.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('Просмотренные', style: TextStyle(fontWeight: FontWeight.w600))),
        for (final st in seen) ListTile(leading: ring(st), title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(st.time), onTap: () => open(st)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Статусы исчезают через 24 часа.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ),
      ]),
    );
  }
}

class StatusViewer extends StatefulWidget {
  final StatusItem item;
  const StatusViewer({super.key, required this.item});
  @override
  State<StatusViewer> createState() => _StatusViewerState();
}

class _StatusViewerState extends State<StatusViewer> with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  int index = 0;

  @override
  void initState() {
    super.initState();
    ctl.addStatusListener((st) {
      if (st == AnimationStatus.completed) next();
    });
    ctl.forward();
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void next() {
    if (index < widget.item.texts.length - 1) {
      setState(() => index++);
      ctl.forward(from: 0);
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  void prev() {
    if (index > 0) setState(() => index--);
    ctl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => d.localPosition.dx < MediaQuery.of(context).size.width / 3 ? prev() : next(),
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF1B2A6B), it.color])),
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(children: [
                  for (var i = 0; i < it.texts.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedBuilder(
                          animation: ctl,
                          builder: (context, _) => LinearProgressIndicator(
                            value: i < index ? 1 : (i == index ? ctl.value : 0),
                            minHeight: 3,
                            backgroundColor: Colors.white30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              ListTile(
                leading: Avatar(it.initials, it.color, size: 40),
                title: Text(it.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(it.time, style: const TextStyle(color: Colors.white70)),
                trailing: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(it.texts[index], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------- Орбиты ----------

class OrbitsPage extends StatelessWidget {
  const OrbitsPage({super.key});

  ChatItem? find(String name) {
    for (final c in chatItems) {
      if (c.name == name) return c;
    }
    return null;
  }

  String kind(ChatItem c) => c.channel ? 'канал' : (c.group ? 'группа' : 'чат');

  void open(BuildContext context, ChatItem c) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => c.channel ? ChannelPage(item: c) : ConversationPage(item: c)),
      );

  Widget card(BuildContext context, Orbit o) {
    final cs = Theme.of(context).colorScheme;
    final found = [for (final n in o.items) if (find(n) != null) find(n)!];
    final chats = found.where((c) => !c.channel).length;
    final channels = found.where((c) => c.channel).length;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: o.color, child: const Icon(Icons.public, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                Text('$chats чатов · $channels каналов', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'del') {
                  orbits.remove(o);
                  if (orbitFilter.value == o.name) orbitFilter.value = null;
                  orbitsRevision.value++;
                  chatsRevision.value++;
                }
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('Удалить орбиту'))],
            ),
          ]),
          if (found.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('В орбите пока пусто', style: TextStyle(color: cs.onSurfaceVariant))),
          for (final c in found)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => open(context, c),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(c.name), Text(kind(c), style: TextStyle(color: cs.onSurfaceVariant))]),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: orbitsRevision,
      builder: (context, _, __) => Scaffold(
        appBar: AppBar(title: const Text('Орбиты', style: TextStyle(fontWeight: FontWeight.bold))),
        body: ListView(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Чаты, группы и каналы по одной теме в одном месте. Орбиту можно выбрать как фильтр на экране «Чаты».'),
          ),
          for (final o in orbits) card(context, o),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NewOrbitPage())),
              child: const Padding(padding: EdgeInsets.all(12), child: Text('Создать орбиту')),
            ),
          ),
        ]),
      ),
    );
  }
}

class NewOrbitPage extends StatefulWidget {
  const NewOrbitPage({super.key});
  @override
  State<NewOrbitPage> createState() => _NewOrbitPageState();
}

class _NewOrbitPageState extends State<NewOrbitPage> {
  static const palette = [seed, teal, rust, Color(0xFF7C3AED), Color(0xFF1B6FB3)];
  final name = TextEditingController();
  Color color = seed;
  final picked = <String>{};

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  bool get valid => name.text.trim().isNotEmpty && !orbits.any((o) => o.name.toLowerCase() == name.text.trim().toLowerCase());

  void create() {
    orbits.add(Orbit(name.text.trim(), color, picked.toList()));
    orbitsRevision.value++;
    chatsRevision.value++;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final taken = name.text.trim().isNotEmpty && !valid;
    return Scaffold(
      appBar: AppBar(title: const Text('Новая орбита')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: name,
          maxLength: 40,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: 'Название темы', helperText: 'Например: Работа, Спорт, Друзья', errorText: taken ? 'Такая орбита уже есть' : null, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        const Text('Цвет', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          for (final c in palette)
            GestureDetector(
              onTap: () => setState(() => color = c),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: color == c ? Colors.white : Colors.transparent, width: 3), boxShadow: color == c ? [BoxShadow(color: c, blurRadius: 6)] : null),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Text('Что добавить в орбиту (${picked.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
        for (final c in chatItems)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Avatar(c.initials, c.color, size: 44),
            title: Text(c.name),
            subtitle: Text(c.channel ? 'канал' : (c.group ? 'группа' : 'чат')),
            value: picked.contains(c.name),
            onChanged: (v) => setState(() => v == true ? picked.add(c.name) : picked.remove(c.name)),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: valid ? create : null, child: const Padding(padding: EdgeInsets.all(14), child: Text('Создать орбиту'))),
      ]),
    );
  }
}

// ---------- Профиль ----------

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: EdgeInsets.zero, children: [
      Container(height: 150, decoration: const BoxDecoration(gradient: LinearGradient(colors: [seed, teal]))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Transform.translate(
          offset: const Offset(0, -40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 42, backgroundColor: cs.surface, child: const Avatar('ВЫ', seed, size: 76)),
            const SizedBox(height: 8),
            Text(Session.name.isEmpty ? 'Ваше имя' : Session.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(Session.phone.isEmpty ? '@username' : Session.phone, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            const Text('Короткое описание профиля.'),
            const SizedBox(height: 12),
            const Row(children: [
              Text('128 ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('подписчиков'),
              SizedBox(width: 24),
              Text('64 ', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('подписок'),
            ]),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Настройки'),
            ),
            const SizedBox(height: 12),
            const Wrap(spacing: 8, children: [
              Chip(label: Text('Видео'), backgroundColor: seed, labelStyle: TextStyle(color: Colors.white)),
              Chip(label: Text('Сохранённое')),
              Chip(label: Text('Репосты')),
            ]),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 3 / 4,
              children: [
                for (final c in const [seed, teal, rust])
                  Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10))),
              ],
            ),
          ]),
        ),
      ),
    ]);
  }
}

// Первый запуск: приветствие, затем регистрация, дальше сразу главное приложение.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? onboarded;
  bool registered = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      Session.phone = p.getString('phone') ?? '';
      Session.name = p.getString('name') ?? '';
      if (mounted) {
        setState(() {
          onboarded = p.getBool('onboarded') ?? false;
          registered = p.getBool('registered') ?? false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => onboarded = false);
    });
  }

  Future<void> _save(void Function(SharedPreferences p) f) async {
    try {
      f(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  Future<void> finishOnboarding() async {
    await _save((p) => p.setBool('onboarded', true));
    if (mounted) setState(() => onboarded = true);
  }

  Future<void> finishRegister() async {
    await _save((p) {
      p.setBool('registered', true);
      p.setString('phone', Session.phone);
      p.setString('name', Session.name);
    });
    if (mounted) setState(() => registered = true);
  }

  @override
  Widget build(BuildContext context) {
    final o = onboarded;
    if (o == null) return const Scaffold(backgroundColor: Color(0xFF040716));
    if (!o) return Onboarding(onDone: finishOnboarding);
    if (!registered) return RegisterFlow(onDone: finishRegister);
    return const Shell();
  }
}
