// Inisialisasi library
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bahasa_jepun/bahasa_jepun.dart';
import "math_speed/math.dart";
import 'passwrod_generator/pasgen.dart';

/// Notifier untuk mode gelap
final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

/// Fungsi untuk memuat preferensi dark mode dari SharedPreferences
Future<bool> loadDarkMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('darkMode') ?? false;
}

/// Fungsi untuk menyimpan preferensi dark mode
Future<void> saveDarkMode(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('darkMode', value);
}

// Fungsi main
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _darkModeFuture;

  @override
  void initState() {
    super.initState();
    _darkModeFuture = loadDarkMode();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _darkModeFuture,
      builder: (context, snapshot) {
        final isDarkMode = snapshot.data ?? false;
        darkModeNotifier.value = isDarkMode;

        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => QuizProvider()),
            ChangeNotifierProvider(create: (_) => RecordProvider()),
          ],
          child: ValueListenableBuilder<bool>(
            valueListenable: darkModeNotifier,
            builder: (context, isDarkMode, child) {
              return MaterialApp(
                title: 'Ruang VIP',
                theme: ThemeData(
                    fontFamily: 'Roboto', brightness: Brightness.light),
                darkTheme: ThemeData(brightness: Brightness.dark),
                themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
                home: const MainPage(),
              );
            },
          ),
        );
      },
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

/// Fungsi untuk inisialisasi halaman
class _MainPageState extends State<MainPage> {
  int _selectedIndex = 1; // Profil sebagai halaman default

  static const List<Widget> _pages = <Widget>[
    PengaturanPage(), // Halaman Pengaturan 0
    PlaceholderWidget(), // Halaman Profil 1
    BahasaJepun(), // Halaman Belajar Bahasa Jepang 2
    MathApp(), // Halaman Math App 3
    PasswordGeneratorPage(), // Halaman Password Generator 4
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Menutup Drawer setelah memilih item
  }

  /// Fungsi untuk tampilan navigasi dan pengaturan halaman
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruang Pribadi'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu Navigasi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () => _onItemTapped(0),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Belajar Alfabet Jepang'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Math Speedup'),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Pasgen'),
              selected: _selectedIndex == 4,
              onTap: () => _onItemTapped(4),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex], // Menampilkan halaman yang dipilih
    );
  }
}

/// Fungsi untuk halaman pengaturan/setting
class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: darkModeNotifier,
          builder: (context, isDarkMode, child) {
            return SwitchListTile(
              title: const Text('Mode Gelap'),
              value: isDarkMode,
              onChanged: (bool value) {
                darkModeNotifier.value = value;
                saveDarkMode(value); // Simpan ke SharedPreferences
              },
            );
          },
        ),
      ),
    );
  }
}

class PlaceholderWidget extends StatelessWidget {
  const PlaceholderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Ruang Pilihan'),
    );
  }
}
