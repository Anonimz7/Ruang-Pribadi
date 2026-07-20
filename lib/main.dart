import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'math_speed/math.dart';
import 'services/api_client.dart';
import 'services/apis.dart';
import 'services/app_registry.dart';
import 'services/dark_mode_service.dart';
import 'widgets/app_drawer.dart';
import 'widgets/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _darkFuture;

  @override
  void initState() {
    super.initState();
    _darkFuture = loadDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _darkFuture,
      builder: (ctx, snap) {
        darkModeNotifier.value = snap.data ?? false;
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => QuizProvider()),
            ChangeNotifierProvider(create: (_) => RecordProvider()),
          ],
          child: ValueListenableBuilder<bool>(
            valueListenable: darkModeNotifier,
            builder: (ctx, isDark, _) => MaterialApp(
              title: 'Ruang VIP',
              theme: ThemeData(fontFamily: 'Roboto', brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home: const MainPage(),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════
// MAIN PAGE
// ═══════════════════════════════════════════════════

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 1;
  final _client = ApiClient();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _client.loadSession();
    if (_client.isLoggedIn) {
      try { await AuthApi().me(); } catch (_) {}
    }
    setState(() => _loading = false);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  /// Build page based on index — checks permissions
  Widget _buildPage(int index) {
    final app = appRegistry[index];

    // system (settings, profile) = selalu bisa
    if (app.section == 'system') return app.builder(context);

    // admin section = owner only
    if (app.section == 'admin') {
      if (_client.tier == 'owner') return app.builder(context);
      return _noAccess(app);
    }

    // fitur lain = butuh login + permission
    if (!_client.isLoggedIn) {
      return LoginScreen(onSuccess: () async {
        await _client.loadSession();
        setState(() {});
      });
    }

    if (_client.canAccess(app.key)) return app.builder(context);

    return _noAccess(app);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Ruang Pribadi')),
      drawer: AppDrawer(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        client: _client,
        onLogout: () async {
          await _client.clearSession();
          setState(() => _selectedIndex = 1);
        },
      ),
      body: _buildPage(_selectedIndex),
    );
  }

  Widget _noAccess(AppDef app) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Akses Terbatas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Anda belum memiliki akses ke "${app.label}".\nHubungi admin untuk mendapatkan izin.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
