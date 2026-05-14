import 'package:flutter/material.dart';
import 'chat_list_tab.dart';
import 'discover_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _tabs = const [
    ChatListTab(),
    DiscoverTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
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
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
