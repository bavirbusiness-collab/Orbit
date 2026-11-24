import 'dart:math' as math;
import 'package:flutter/material.dart';

// Приветственные окна Orbit: 1 приветствие, 2 о приложении, 3 условия,
// 4 доступы (контакты и файлы), 5 о разработчике и пожертвования.
// Это макет: запросы разрешений и оплата пока не подключены.

const _bgTop = Color(0xFF040716);
const _bgBottom = Color(0xFF0C1445);
const _accent = Color(0xFF7C8CFF);
const _teal = Color(0xFF2FD3B5);

class Onboarding extends StatefulWidget {
  final VoidCallback onDone;
  const Onboarding({super.key, required this.onDone});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final controller = PageController();
  int page = 0;
  bool accepted = false;
  static const total = 5;

  void go(int p) => controller.animateToPage(p, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);

  bool get canNext => page != 2 || accepted;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = page == total - 1;
    return Theme(
      data: ThemeData(colorSchemeSeed: _accent, brightness: Brightness.dark, useMaterial3: true),
      child: Scaffold(
        backgroundColor: _bgTop,
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom])),
          child: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: StarsPainter())),
            SafeArea(
              child: Column(children: [
                Expanded(
                  child: PageView(
                    controller: controller,
                    physics: canNext ? const PageScrollPhysics() : const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => page = i),
                    children: [
                      const WelcomePage(),
                      const AboutPage(),
                      TermsPage(accepted: accepted, onChanged: (v) => setState(() => accepted = v)),
                      const PermissionsPage(),
                      const DeveloperPage(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(children: [
                    SizedBox(
                      width: 72,
                      child: page > 0 ? TextButton(onPressed: () => go(page - 1), child: const Text('Назад')) : null,
                    ),
                    Expanded(
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var i = 0; i < total; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == page ? 22 : 7,
                            height: 7,
                            decoration: BoxDecoration(color: i == page ? _accent : Colors.white24, borderRadius: BorderRadius.circular(4)),
                          ),
                      ]),
                    ),
                    SizedBox(
                      width: 110,
                      child: FilledButton(
                        onPressed: !canNext ? null : (last ? widget.onDone : () => go(page + 1)),
                        child: Text(last ? 'Начать' : 'Далее'),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------- фон со звёздами ----------

class StarsPainter extends CustomPainter {
  const StarsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final p = Paint();
    for (var i = 0; i < 110; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.4 + rnd.nextDouble() * 1.3;
      p.color = Colors.white.withValues(alpha: 0.25 + rnd.nextDouble() * 0.6);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------- 1. Приветствие: Земля, орбитальная станция, сообщение ----------

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Expanded(flex: 5, child: OrbitHero()),
      Expanded(
        flex: 3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
            const Text('Orbit', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w800, letterSpacing: -1, color: Colors.white)),
            const SizedBox(height: 10),
            Text(
              'Станция на орбите соединяет весь мир. Одно сообщение долетает до друга за секунды.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.4, color: Colors.white.withValues(alpha: 0.75)),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class OrbitHero extends StatefulWidget {
  const OrbitHero({super.key});
  @override
  State<OrbitHero> createState() => _OrbitHeroState();
}

class _OrbitHeroState extends State<OrbitHero> with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctl,
      builder: (context, _) => CustomPaint(painter: HeroPainter(ctl.value), size: Size.infinite),
    );
  }
}

class HeroPainter extends CustomPainter {
  final double t; // 0..1, один оборот за цикл
  HeroPainter(this.t);

  static const tilt = -0.44;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.27;
    final rx = r * 1.95;
    final ry = r * 0.58;

    // свечение атмосферы
    canvas.drawCircle(
      c,
      r * 2.1,
      Paint()..shader = const RadialGradient(colors: [Color(0x553B8BFF), Color(0x00000000)]).createShader(Rect.fromCircle(center: c, radius: r * 2.1)),
    );

    // Земля
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.4),
          colors: [Color(0xFF58BBFF), Color(0xFF1B4DB3), Color(0xFF081B52)],
          stops: [0, 0.6, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // материки: вращаются вместе с Землёй
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final land = Paint()..color = const Color(0xFF34C98B).withValues(alpha: 0.85);
    const blobs = [(0.0, -0.25, 0.30), (2.1, 0.30, 0.22), (4.2, -0.05, 0.26)];
    for (final b in blobs) {
      final a = b.$1 + 2 * math.pi * t;
      final depth = math.cos(a);
      if (depth > -0.15) {
        final x = c.dx + r * 0.95 * math.sin(a);
        final y = c.dy + r * b.$2;
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * b.$3 * 2 * (0.4 + 0.6 * depth.abs()), height: r * b.$3 * 1.5), land);
      }
    }
    canvas.restore();

    // тень по краю
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: const [Color(0x00000000), Color(0x88000000)], stops: const [0.6, 1]).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // орбита
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    // станция
    final th = 2 * math.pi * t;
    final sx = rx * math.cos(th);
    final sy = ry * math.sin(th);
    final sat = Offset(sx, sy);
    final body = Paint()..color = Colors.white;
    final panel = Paint()..color = _accent;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: sat, width: 14, height: 10), const Radius.circular(3)), body);
    canvas.drawRect(Rect.fromCenter(center: sat + const Offset(-14, 0), width: 14, height: 6), panel);
    canvas.drawRect(Rect.fromCenter(center: sat + const Offset(14, 0), width: 14, height: 6), panel);
    canvas.restore();

    // сообщение летит со станции к Земле
    final cosT = math.cos(tilt);
    final sinT = math.sin(tilt);
    final satWorld = Offset(c.dx + sx * cosT - sy * sinT, c.dy + sx * sinT + sy * cosT);
    final toEarth = c - satWorld;
    final dist = toEarth.distance;
    if (dist > 0) {
      final dir = toEarth / dist;
      final end = c - dir * r * 0.98;
      final line = Paint()
        ..color = _teal.withValues(alpha: 0.35)
        ..strokeWidth = 1.2;
      const dashes = 14;
      for (var i = 0; i < dashes; i += 2) {
        canvas.drawLine(Offset.lerp(satWorld, end, i / dashes)!, Offset.lerp(satWorld, end, (i + 1) / dashes)!, line);
      }
      final u = (t * 4) % 1.0;
      final pos = Offset.lerp(satWorld, end, u)!;
      canvas.drawCircle(pos, 9, Paint()..color = _teal.withValues(alpha: 0.25));
      canvas.drawCircle(pos, 4.5, Paint()..color = _teal);
    }
  }

  @override
  bool shouldRepaint(covariant HeroPainter old) => old.t != t;
}

// ---------- общие куски ----------

class PageShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const PageShell({super.key, required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: _accent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: _accent, size: 30),
        ),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
        const SizedBox(height: 20),
        ...children,
      ]),
    );
  }
}

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? trailing;
  const InfoCard({super.key, required this.icon, required this.title, required this.text, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _teal),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: Colors.white.withValues(alpha: 0.75))),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ---------- 2. О приложении ----------

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const PageShell(
      icon: Icons.public,
      title: 'Всё общение\nна одной орбите',
      children: [
        InfoCard(icon: Icons.chat_bubble_outline, title: 'Чаты и группы', text: 'Личные переписки, группы и временные комнаты для поездок и событий.'),
        InfoCard(icon: Icons.play_circle_outline, title: 'Reals', text: 'Короткие вертикальные видео и ответ видео прямо из чата.'),
        InfoCard(icon: Icons.blur_circular, title: 'Орбиты', text: 'Чаты, каналы и видео по одной теме собраны в одном месте.'),
        InfoCard(icon: Icons.notifications_paused_outlined, title: 'Режим «Тишина»', text: 'Никаких бесконечных уведомлений: вы получаете дайджест того, что пропустили.'),
      ],
    );
  }
}

// ---------- 3. Условия использования ----------

class TermsPage extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;
  const TermsPage({super.key, required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget item(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(padding: EdgeInsets.only(top: 7, right: 10), child: Icon(Icons.circle, size: 6, color: _teal)),
            Expanded(child: Text(s, style: TextStyle(fontSize: 15, height: 1.4, color: Colors.white.withValues(alpha: 0.85)))),
          ]),
        );
    return PageShell(
      icon: Icons.description_outlined,
      title: 'Условия использования',
      children: [
        item('Вы отвечаете за то, что пишете и публикуете.'),
        item('Спам, оскорбления, обман и незаконный контент запрещены.'),
        item('Аккаунт, который нарушает правила, мы можем ограничить.'),
        item('Orbit сейчас в бета-версии: возможны ошибки и изменения.'),
        item('Полный текст условий и политика конфиденциальности будут доступны в приложении.'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)),
          child: CheckboxListTile(
            value: accepted,
            onChanged: (v) => onChanged(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Я принимаю условия использования', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

// ---------- 4. Доступы ----------

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});
  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  // Макет: переключатели пока ничего не запрашивают у системы.
  bool contacts = false;
  bool files = false;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      icon: Icons.verified_user_outlined,
      title: 'Какой доступ\nмы просим и зачем',
      children: [
        InfoCard(
          icon: Icons.contacts_outlined,
          title: 'Контакты',
          text: 'Чтобы найти друзей, которые уже в Orbit. Мы не пишем вашим контактам без вашего ведома.',
          trailing: Switch(value: contacts, onChanged: (v) => setState(() => contacts = v)),
        ),
        InfoCard(
          icon: Icons.folder_outlined,
          title: 'Файлы и медиа',
          text: 'Чтобы вы могли отправлять фото, видео и документы. Мы видим только то, что вы сами выбрали.',
          trailing: Switch(value: files, onChanged: (v) => setState(() => files = v)),
        ),
        const SizedBox(height: 4),
        Text(
          'Мы ничего не берём втайне: доступ нужен только для функций, которые вы запускаете сами. Он необязателен и отключается в настройках телефона в любой момент.',
          style: TextStyle(fontSize: 14, height: 1.4, color: Colors.white.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

// ---------- 5. О разработчике ----------

class DeveloperPage extends StatelessWidget {
  const DeveloperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      icon: Icons.code,
      title: 'О разработчике',
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const CircleAvatar(radius: 28, backgroundColor: _accent, child: Icon(Icons.person, color: Colors.white, size: 30)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // TODO: заменить на настоящее имя и ссылку
                Text('[Ваше имя]', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Автор и разработчик Orbit', style: TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(
          'Orbit делается шаг за шагом. Если приложение вам нравится, вы можете поддержать дальнейшую разработку. Это полностью по желанию.',
          style: TextStyle(fontSize: 15, height: 1.45, color: Colors.white.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Способ пожертвования появится позже'))),
            icon: const Icon(Icons.favorite_border),
            label: const Padding(padding: EdgeInsets.all(12), child: Text('Поддержать разработку')),
          ),
        ),
      ],
    );
  }
}
