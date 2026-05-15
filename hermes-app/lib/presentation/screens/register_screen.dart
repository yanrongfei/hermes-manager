import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/auth_provider.dart';
import '../widgets/tg_toast.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).register(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) {
        TGToast.show(context, message: error, type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 80),
                Image.asset('assets/images/hermesagent.png', width: 72, height: 72),
                const SizedBox(height: 16),
                const Text(
                  '创建账号',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFECECEC),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Color(0xFFECECEC)),
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    prefixIcon: Icon(Icons.person_outline, color: Color(0xFFA0A0A0)),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  validator: (v) {
                    if (v?.isEmpty == true) return '请输入用户名';
                    if (v!.length < 3) return '至少 3 个字符';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Color(0xFFECECEC)),
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFA0A0A0)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xFFA0A0A0),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  validator: (v) {
                    if (v?.isEmpty == true) return '请输入密码';
                    if (v!.length < 6) return '至少 6 个字符';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFFECECEC)),
                  decoration: const InputDecoration(
                    labelText: '确认密码',
                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFA0A0A0)),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) return '两次密码不一致';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _register,
                  child: authState.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('注册', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text(
                    '已有账号？去登录',
                    style: TextStyle(color: Color(0xFFA0A0A0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
