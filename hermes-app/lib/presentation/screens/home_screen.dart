import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/notification_provider.dart';
import '../../data/providers/room_provider.dart';
import '../../data/providers/storage_provider.dart';
import 'chat_list_tab.dart';
import 'discover_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _authChecked = false;

  final _tabs = const [
    ChatListTab(),
    DiscoverTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    // 1. Already in memory (navigated from splash after login)
    if (ref.read(authProvider).isAuthenticated) {
      if (mounted) setState(() => _authChecked = true);
      return;
    }

    // 2. Check storage — token is the source of truth
    final storage = ref.read(storageProvider);
    final token = await storage.get(AppConfig.accessTokenKey);
    if (token == null) {
      // No token at all → must login
      if (mounted) context.go('/login');
      return;
    }

    // 3. Token exists → try to validate and load user info
    //    If validation fails, still trust the token (could be network blip)
    await ref.read(authProvider.notifier).checkAuth();

    // 4. Regardless of API result, if we have a token we stay in the app
    if (!mounted) return;
    setState(() => _authChecked = true);

    // 5. Connect notification WS for real-time room updates
    ref.read(notificationProvider.notifier).connect();
  }

  @override
  Widget build(BuildContext context) {
    if (!_authChecked) {
      return const Scaffold(
        backgroundColor: Color(0xFF212121),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2A2A2A),
          border: Border(
            top: BorderSide(color: Color(0xFF3A3A3A)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFF2A2A2A),
          indicatorColor: const Color(0xFF5856D6).withAlpha(50),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
            ref.read(currentTabProvider.notifier).state = index;
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline, color: Color(0xFFA0A0A0)),
              selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF5856D6)),
              label: '对话',
            ),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined, color: Color(0xFFA0A0A0)),
              selectedIcon: Icon(Icons.explore, color: Color(0xFF5856D6)),
              label: '发现',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: Color(0xFFA0A0A0)),
              selectedIcon: Icon(Icons.person, color: Color(0xFF5856D6)),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}
