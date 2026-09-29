import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    Env.check();
  } on StateError catch (e) {
    runApp(_ConfigErrorApp(e.message));
    return;
  }
  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
  runApp(const ProviderScope(child: BhutanServicesApp()));
}

/// For developers: shows a config problem on screen instead of a blank app.
class _ConfigErrorApp extends StatelessWidget {
  final String message;

  const _ConfigErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}
