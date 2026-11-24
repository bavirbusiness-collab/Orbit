import 'package:flutter/material.dart';

// Макет «Орбиты»: все данные выдуманные, сервера нет. Реальная логика лежит в папке later/.

void main() => runApp(const OrbitaMock());

const seed = Color(0xFF3B4CCA);
const teal = Color(0xFF0F8F7E);
const rust = Color(0xFFC2410C);

class OrbitaMock extends StatelessWidget {
  const OrbitaMock({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Орбита',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: const Shell(),
    );
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
    const pages = [ChatsPage(), RealsPage(), OrbitsPage(), ProfilePage()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Чаты'),
          NavigationDestination(icon: Icon(Icons.play_circle_outline), selectedIcon: Icon(Icons.play_circle), label: 'Reals'),
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
  const ChatItem(this.name, this.last, this.time, this.initials, this.color, [this.unread = 0]);
}

const chatItems = [
  ChatItem('Руслан', 'Завтра на озеро в семь?', '11:42', 'Р', seed, 2),
  ChatItem('Группа 11-Б', 'Лейла: конспект уже в канале', '10:15', 'Г', teal),
  ChatItem('Поездка в Шеки', 'Комната закроется через 6 дней', 'вчера', 'Ш', rust),
  ChatItem('Мама', 'Видео-ответ · 0:14', 'вчера', 'М', Color(0xFF5A6280)),
];

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаты', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline))],
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(hintText: 'Поиск людей, чатов, видео', leading: const Icon(Icons.search), elevation: const WidgetStatePropertyAll(0)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(spacing: 8, children: [
            Chip(label: Text('Все'), backgroundColor: seed, labelStyle: TextStyle(color: Colors.white)),
            Chip(label: Text('Рыбалка')),
            Chip(label: Text('Учёба')),
            Chip(label: Text('Семья')),
          ]),
        ),
        for (final c in chatItems)
          ListTile(
            leading: Avatar(c.initials, c.color),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.last, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(c.time, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              if (c.unread > 0) Badge(label: Text('${c.unread}')),
            ]),
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ConversationPage(item: c))),
          ),
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

class ConversationPage extends StatelessWidget {
  final ChatItem item;
  const ConversationPage({super.key, required this.item});

  Widget bubble(BuildContext context, String text, bool mine, {String? sub}) {
    final cs = Theme.of(context).colorScheme;
    final fg = mine ? cs.onPrimary : cs.onSurfaceVariant;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(color: mine ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: TextStyle(color: fg)),
          if (sub != null) Text(sub, style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Avatar(item.initials, item.color, size: 38),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Text('печатает…', style: TextStyle(fontSize: 12, color: teal)),
          ]),
        ]),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: cs.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text('Закреплено: Сбор у моста в 6:40', style: TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(14), children: [
            bubble(context, 'Завтра на озеро в семь?', false),
            bubble(context, 'Давай в 6:40, пока клёв. Возьму термос.', true),
            bubble(context, 'Голос · 0:21\n«…возьми удочку побольше, там глубоко…»', false, sub: 'Расшифровка на устройстве'),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file)),
              const Expanded(child: TextField(decoration: InputDecoration(hintText: 'Сообщение', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)))))),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: () {}, icon: const Icon(Icons.videocam_outlined)),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ---------- Reals ----------

class RealsPage extends StatelessWidget {
  const RealsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const clips = [
      ('@leyla', 'Рассвет на озере: лёгкая снасть #рыбалка', 'Рыбалка', [Color(0xFF1B2A6B), teal]),
      ('@rustam', 'Как за вечер выучить 30 слов #учёба', 'Учёба', [Color(0xFF3B1B6B), seed]),
      ('@nigar', 'Шеки за один день #поездка', 'Шеки', [Color(0xFF6B2A1B), rust]),
    ];
    return PageView(
      scrollDirection: Axis.vertical,
      children: [
        for (final c in clips)
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: c.$4)),
            child: SafeArea(
              child: Stack(children: [
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Подписки', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
                      SizedBox(width: 24),
                      Text('Для вас', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: Colors.white)),
                    ]),
                  ),
                ),
                const Positioned(
                  right: 12,
                  bottom: 24,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite_border, color: Colors.white, size: 32),
                    Text('12,4 тыс.', style: TextStyle(color: Colors.white, fontSize: 12)),
                    SizedBox(height: 18),
                    Icon(Icons.chat_bubble_outline, color: Colors.white, size: 30),
                    Text('318', style: TextStyle(color: Colors.white, fontSize: 12)),
                    SizedBox(height: 18),
                    Icon(Icons.send_outlined, color: Colors.white, size: 30),
                    Text('В чат', style: TextStyle(color: Colors.white, fontSize: 12)),
                    SizedBox(height: 18),
                    Icon(Icons.bookmark_border, color: Colors.white, size: 30),
                  ]),
                ),
                Positioned(
                  left: 16,
                  right: 80,
                  bottom: 24,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(c.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(c.$2, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    Chip(label: Text('Орбита: ${c.$3}'), backgroundColor: Colors.white24, labelStyle: const TextStyle(color: Colors.white), side: BorderSide.none),
                  ]),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

// ---------- Орбиты ----------

class OrbitsPage extends StatelessWidget {
  const OrbitsPage({super.key});

  Widget card(BuildContext context, Color color, String title, String sub, [List<(String, String)> items = const []]) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: color, child: const Icon(Icons.public, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              Text(sub, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ])),
          ]),
          for (final it in items)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(it.$1), Text(it.$2, style: TextStyle(color: cs.onSurfaceVariant))]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Орбиты', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Чаты, каналы и видео по одной теме в одном месте.'),
        ),
        card(context, seed, 'Рыбалка', '2 чата · 1 канал · 24 видео', const [('Руслан', 'чат'), ('Клёв на Мингечевире', 'канал'), ('Видео по теме', '24 ролика')]),
        card(context, teal, 'Учёба', '1 группа · 3 канала'),
        card(context, rust, 'Поездка в Шеки', 'временная комната · закроется через 6 дней'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton(onPressed: () {}, child: const Padding(padding: EdgeInsets.all(12), child: Text('Создать орбиту'))),
        ),
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
            const Text('Ваше имя', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('@username', style: TextStyle(color: cs.onSurfaceVariant)),
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
