import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../data/providers/storage_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Delay for splash effect
    await Future.delayed(const Duration(seconds: 1));

    final storage = ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (!mounted) return;

    if (token != null) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/hermesagent.png', width: 96, height: 96),
            const SizedBox(height: 16),
            Text(
              'Hermes Agent',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFECECEC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
