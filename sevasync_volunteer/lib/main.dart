import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'main_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ⚠️  Replace these with your real Supabase project credentials.
//     You can find them in: Supabase Dashboard → Settings → API
// ─────────────────────────────────────────────────────────────────────────────
const _supabaseUrl     = 'https://nnlcnsflmxcbaynbequa.supabase.co';       // e.g. https://abcdef.supabase.co
const _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ubGNuc2ZsbXhjYmF5bmJlcXVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxOTEzNjcsImV4cCI6MjA5MTc2NzM2N30.m3ECuAm3iuS391dD89YTj74kRqq9cRxXJxhGa-IqYE8';  // starts with "eyJ..."

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style to match dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.light,
      statusBarBrightness:      Brightness.dark,
    ),
  );

  await Supabase.initialize(
    url:     _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const SevaSyncApp());
}

// ─────────────────────────────────────────────────────────────────────────────
class SevaSyncApp extends StatelessWidget {
  const SevaSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                    'Sevasync AI',
      debugShowCheckedModeBanner: false,
      theme:                    AppTheme.light,
      home:                     const AuthGate(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthGate – listens to Supabase auth state changes and routes accordingly.
// ─────────────────────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // While waiting for the first event, show the splash
        if (!snapshot.hasData) {
          return const _SplashScreen();
        }

        final session = snapshot.data!.session;
        return session != null ? const MainShell() : const LoginScreen();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Splash screen shown briefly on cold start
// ─────────────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.jpeg', width: 80, height: 80),
            const SizedBox(height: 16),
            RichText(text: const TextSpan(children: [
              TextSpan(text: 'SEVA', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                  color: AppColors.teal, letterSpacing: 1)),
              TextSpan(text: 'SYNC', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                  color: AppColors.orange, letterSpacing: 1)),
            ])),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}
