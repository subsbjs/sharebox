import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.load();

  if (!AppConfig.isConfigured) {
    runApp(const ConfigurationMissingApp());
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  runApp(ShareBoxApp(settings: settings));
}

class ShareBoxApp extends StatefulWidget {
  const ShareBoxApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<ShareBoxApp> createState() => _ShareBoxAppState();
}

class _ShareBoxAppState extends State<ShareBoxApp> {
  Session? _session;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _session = client.auth.currentSession;
    _authSubscription = client.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      setState(() => _session = event.session);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShareBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: _session == null
          ? const AuthScreen()
          : HomeScreen(settings: widget.settings),
    );
  }
}

class ConfigurationMissingApp extends StatelessWidget {
  const ConfigurationMissingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ShareBox 尚未连接 Supabase',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '复制 config.example.json 为 config.local.json，填入项目 URL 和 Publishable/Anon Key，然后使用项目自带的构建脚本启动。',
                      ),
                      const SizedBox(height: 18),
                      SelectableText(
                        'flutter run -d windows --dart-define-from-file=config.local.json',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
