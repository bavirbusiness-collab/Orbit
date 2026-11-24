import 'package:flutter/material.dart';
import 'screens.dart';
import 'state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OrbitaApp());
}

class OrbitaApp extends StatefulWidget {
  const OrbitaApp({super.key});
  @override
  State<OrbitaApp> createState() => _OrbitaAppState();
}

class _OrbitaAppState extends State<OrbitaApp> {
  final st = AppState();

  @override
  void initState() {
    super.initState();
    st.init();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3B4CCA);
    return MaterialApp(
      title: 'Орбита',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: ListenableBuilder(
        listenable: st,
        builder: (context, _) {
          if (!st.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final root = st.screen == Screen.chats || st.screen == Screen.login || st.screen == Screen.profile;
          return PopScope(
            canPop: root,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) st.back();
            },
            child: Root(st: st),
          );
        },
      ),
    );
  }
}
