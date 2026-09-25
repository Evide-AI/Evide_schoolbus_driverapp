import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Drivers and conductors are created with a phone number in the dashboard, and
// that number is their login. Behind the scenes it maps to an internal email
// (Supabase's own phone login needs a paid SMS provider), which is why the
// phone path just builds that address instead of asking the server.
String _phoneToLoginEmail(String input) {
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return '91$d@driver.evide.in';
}

enum _LoginMode { phone, email }

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  _LoginMode _mode = _LoginMode.phone;
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _phoneLooksValid =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(_phoneCtrl.text.replaceAll(RegExp(r'\D'), ''));

  Future<void> _signIn() async {
    if (_mode == _LoginMode.phone && !_phoneLooksValid) {
      setState(() => _error = 'Enter your 10-digit mobile number.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _mode == _LoginMode.phone
            ? _phoneToLoginEmail(_phoneCtrl.text)
            : _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      // AuthGate listens to auth state and swaps to the roster automatically.
    } on AuthException catch (e) {
      setState(() {
        _error = e.message == 'Invalid login credentials'
            ? (_mode == _LoginMode.phone
                ? 'Mobile number or password is incorrect.'
                : 'Email or password is incorrect.')
            : e.message;
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong. Check your connection and try again.';
        _submitting = false;
      });
    }
  }

  Widget _modeTab(_LoginMode value, String label) {
    final selected = _mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: _submitting
            ? null
            : () => setState(() {
                  _mode = value;
                  _error = null;
                }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.ink : AppColors.inkFaint,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Image.asset('assets/evide-logo.png', height: 44),
                  ),
                  const SizedBox(height: 24),
                  const Text('Driver sign in',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 6),
                  const Text('Sign in to mark student attendance.',
                      style: TextStyle(color: AppColors.inkFaint)),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        _modeTab(_LoginMode.phone, 'Mobile number'),
                        _modeTab(_LoginMode.email, 'Email'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.stopSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_error!,
                          style: const TextStyle(color: AppColors.stop)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_mode == _LoginMode.phone)
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixText: '+91 ',
                      ),
                    )
                  else
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _submitting ? null : _signIn(),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _submitting ? null : _signIn,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(_submitting ? 'Signing in…' : 'Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
