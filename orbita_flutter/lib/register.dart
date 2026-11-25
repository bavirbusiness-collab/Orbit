import 'dart:async';
import 'package:flutter/material.dart';
import 'live.dart';
import 'onboarding.dart' show StarsPainter;

// Регистрация как в WhatsApp: 1 номер телефона, 2 код из SMS, 3 имя (обязательно) и фото (по желанию).
// Тестовый режим: SMS-провайдер ещё не подключён, сервер показывает код на экране. Фото пока не загружается.

const _bgTop = Color(0xFF040716);
const _bgBottom = Color(0xFF0C1445);
const _accent = Color(0xFF7C8CFF);
const _teal = Color(0xFF2FD3B5);

/// Данные текущего пользователя (пока только в памяти макета).
class Session {
  static String phone = '';
  static String name = '';
  static String about = '';
  static bool hasPhoto = false;
}

class RegisterFlow extends StatefulWidget {
  final VoidCallback onDone;
  const RegisterFlow({super.key, required this.onDone});
  @override
  State<RegisterFlow> createState() => _RegisterFlowState();
}

class _RegisterFlowState extends State<RegisterFlow> {
  int stage = 0; // 0 телефон, 1 код, 2 профиль

  @override
  Widget build(BuildContext context) {
    final Widget body;
    switch (stage) {
      case 0:
        body = PhoneStep(onNext: (p) => setState(() {
              Session.phone = p;
              stage = 1;
            }));
        break;
      case 1:
        body = CodeStep(phone: Session.phone, onBack: () => setState(() => stage = 0), onNext: (needsProfile) {
          if (needsProfile) {
            setState(() => stage = 2);
          } else {
            widget.onDone();
          }
        });
        break;
      default:
        body = ProfileStep(onDone: () => widget.onDone());
    }
    return Theme(
      data: ThemeData(colorSchemeSeed: _accent, brightness: Brightness.dark, useMaterial3: true),
      child: PopScope(
        canPop: stage == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => stage = stage == 2 ? 1 : 0);
        },
        child: Scaffold(
          backgroundColor: _bgTop,
          body: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom])),
            child: Stack(children: [
              const Positioned.fill(child: CustomPaint(painter: StarsPainter())),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: body),
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

Widget _title(String t, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 8),
      Text(sub, style: TextStyle(fontSize: 15, height: 1.4, color: Colors.white.withValues(alpha: 0.75))),
      const SizedBox(height: 28),
    ]);

// ---------- 1. Номер телефона ----------

class PhoneStep extends StatefulWidget {
  final void Function(String phone) onNext;
  const PhoneStep({super.key, required this.onNext});
  @override
  State<PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<PhoneStep> {
  static const codes = [
    ('+994', 'Азербайджан'),
    ('+7', 'Россия / Казахстан'),
    ('+90', 'Турция'),
    ('+995', 'Грузия'),
    ('+380', 'Украина'),
    ('+49', 'Германия'),
    ('+1', 'США / Канада'),
  ];
  String code = '+994';
  final phone = TextEditingController();

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  String get digits => phone.text.replaceAll(RegExp(r'\D'), '');
  bool get valid => digits.length >= 7 && digits.length <= 12;

  Future<void> confirm() async {
    final full = '$code $digits';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Проверьте номер'),
        content: Text('Мы отправим SMS с кодом на номер\n$full'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Изменить')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да, верно')),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await live.requestCode(full);
    if (!mounted) return;
    if (sent) {
      widget.onNext(full);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(live.error ?? 'Не удалось отправить код')));
    }
  }

  Future<void> editServer() async {
    final c = TextEditingController(text: live.server);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Адрес сервера'),
        content: TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Сохранить')),
        ],
      ),
    );
    if (v != null) await live.setServer(v);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title('Ваш номер телефона', 'Orbit пришлёт SMS с кодом, чтобы подтвердить, что номер ваш.'),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: DropdownButtonFormField<String>(
            value: code,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Код'),
            items: [for (final c in codes) DropdownMenuItem(value: c.$1, child: Text(c.$1))],
            onChanged: (v) => setState(() => code = v ?? code),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Номер телефона'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(
        'Номер нужен, чтобы вас могли найти друзья. Мы не публикуем его без вашего согласия.',
        style: TextStyle(fontSize: 13, height: 1.4, color: Colors.white.withValues(alpha: 0.6)),
      ),
      const SizedBox(height: 24),
      ListenableBuilder(
        listenable: live,
        builder: (context, _) => FilledButton(
          onPressed: valid && !live.busy ? confirm : null,
          child: Padding(padding: const EdgeInsets.all(14), child: Text(live.busy ? 'Отправляем…' : 'Продолжить')),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: editServer, child: Text('Сервер: ${live.server}', style: const TextStyle(fontSize: 12))),
    ]);
  }
}

// ---------- 2. Код из SMS ----------

class CodeStep extends StatefulWidget {
  final String phone;
  final VoidCallback onBack;
  final void Function(bool needsProfile) onNext;
  const CodeStep({super.key, required this.phone, required this.onBack, required this.onNext});
  @override
  State<CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<CodeStep> {
  final code = TextEditingController();
  Timer? timer;
  int left = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    left = 30;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (left <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => left = left > 0 ? left - 1 : 0);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    super.dispose();
  }

  Future<void> onChanged(String v) async {
    setState(() {});
    if (v.length != 6) return;
    final r = await live.verify(widget.phone, v);
    if (!mounted) return;
    if (r == null) {
      code.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(live.error ?? 'Не удалось проверить код')));
    } else {
      widget.onNext(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = code.text;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title('Введите код', 'Мы отправили SMS на ${widget.phone}.'),
      Stack(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 6; i++)
            Container(
              width: 46,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: i == text.length ? _accent : Colors.white12, width: i == text.length ? 2 : 1),
              ),
              child: Text(i < text.length ? text[i] : '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
        ]),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: code,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      if (live.devCode != null) Text('Тестовый режим. Ваш код: ${live.devCode}', style: TextStyle(fontSize: 14, color: _teal.withValues(alpha: 0.9))),
      const SizedBox(height: 16),
      Center(
        child: left > 0
            ? Text('Отправить код ещё раз через $left с', style: TextStyle(color: Colors.white.withValues(alpha: 0.6)))
            : TextButton(
                onPressed: () async {
                  if (await live.requestCode(widget.phone)) _startTimer();
                },
                child: const Text('Отправить код ещё раз')),
      ),
      Center(child: TextButton(onPressed: widget.onBack, child: const Text('Изменить номер'))),
    ]);
  }
}

// ---------- 3. Имя и фото ----------

class ProfileStep extends StatefulWidget {
  final VoidCallback onDone;
  const ProfileStep({super.key, required this.onDone});
  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  final name = TextEditingController();
  bool hasPhoto = false; // макет: настоящий выбор фото подключим позже

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void pickPhoto() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Сделать фото'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => hasPhoto = true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Выбрать из галереи'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => hasPhoto = true);
            },
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Убрать фото'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => hasPhoto = false);
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = name.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title('Как вас зовут?', 'Имя увидят ваши друзья. Фото можно добавить позже.'),
      Center(
        child: GestureDetector(
          onTap: pickPhoto,
          child: Stack(children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasPhoto ? const LinearGradient(colors: [_accent, _teal]) : null,
                color: hasPhoto ? null : Colors.white.withValues(alpha: 0.08),
              ),
              child: Icon(hasPhoto ? Icons.image : Icons.person, size: 54, color: Colors.white70),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(radius: 18, backgroundColor: _accent, child: const Icon(Icons.add_a_photo, size: 18, color: Colors.white)),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Center(child: Text(hasPhoto ? 'Фото выбрано (в макете условно)' : 'Фото необязательно', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)))),
      const SizedBox(height: 24),
      TextField(
        controller: name,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Ваше имя', helperText: 'Обязательно'),
      ),
      const SizedBox(height: 12),
      ListenableBuilder(
        listenable: live,
        builder: (context, _) => FilledButton(
          onPressed: n.isEmpty || live.busy
              ? null
              : () async {
                  final ok = await live.saveProfile(n, '');
                  if (!context.mounted) return;
                  if (ok) {
                    widget.onDone();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(live.error ?? 'Не удалось сохранить')));
                  }
                },
          child: const Padding(padding: EdgeInsets.all(14), child: Text('Готово')),
        ),
      ),
    ]);
  }
}
