import 'package:flutter/material.dart';
import '../services/apis.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  const LoginScreen({super.key, required this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthApi();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await _auth.login(_userCtrl.text.trim(), _passCtrl.text);
        widget.onSuccess();
      } else {
        await _auth.register(_userCtrl.text.trim(), _passCtrl.text);
        setState(() { _isLogin = true; _error = 'Registrasi berhasil! Silakan login.'; });
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('News Intelligence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(Icons.analytics_outlined, size: 72, color: isDark ? const Color(0xFF00FA9A) : Colors.green),
            const SizedBox(height: 16),
            Text('Login', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: _error!.contains('berhasil') ? Colors.green : Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C87A), foregroundColor: Colors.black),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isLogin ? 'LOGIN' : 'REGISTER'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() { _isLogin = !_isLogin; _error = null; }),
              child: Text(_isLogin ? 'Belum punya akun? Register' : 'Sudah punya akun? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
