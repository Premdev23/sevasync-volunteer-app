import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  Future<void> _signIn() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ── Hero logo ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppColors.teal.withOpacity(0.15),
                          blurRadius: 30, spreadRadius: 2),
                    ],
                  ),
                  child: Image.asset('assets/images/logo.jpeg', width: 80, height: 80),
                ),
                const SizedBox(height: 18),
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(text: 'SEVA',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                            color: AppColors.teal, letterSpacing: 1.5)),
                    TextSpan(text: 'SYNC',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                            color: AppColors.orange, letterSpacing: 1.5)),
                  ]),
                ),
                const SizedBox(height: 6),
                const Text('Intelligent Volunteer Platform',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),

                const SizedBox(height: 36),

                // ── Sign in card ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06),
                          blurRadius: 20, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Header stripe
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.teal, AppColors.green],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(children: [
                        Icon(Icons.volunteer_activism, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Volunteer Sign In',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          Text('Access your volunteer dashboard',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ]),
                      ]),
                    ),

                    const SizedBox(height: 22),

                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.teal),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.teal),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13))),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Sign In'),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
