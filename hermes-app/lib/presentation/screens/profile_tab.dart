import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/auth_provider.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('我的', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: ListView(
        children: [
          // Profile header
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF2A2A2A),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF5856D6),
                  child: Text(
                    (authState.user?.username ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authState.user?.username ?? '未登录',
                        style: const TextStyle(
                          color: Color(0xFFECECEC),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${authState.user?.id ?? ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Settings section
          _SectionHeader(title: '设置'),
          _SettingsTile(
            icon: Icons.settings_outlined,
            title: '应用设置',
            subtitle: '主题、通知、语言',
            onTap: () => _showSettingsSheet(context),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: '通知设置',
            subtitle: '推送通知、免打扰时段',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.devices_outlined,
            title: '多设备管理',
            subtitle: '查看已登录设备',
            onTap: () {},
          ),

          const SizedBox(height: 8),

          // Data section
          _SectionHeader(title: '数据'),
          _SettingsTile(
            icon: Icons.analytics_outlined,
            title: '用量统计',
            subtitle: 'Token 使用量、成本估算',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存',
            subtitle: '清理本地消息缓存',
            onTap: () => _showClearCacheDialog(context),
          ),

          const SizedBox(height: 8),

          // About section
          _SectionHeader(title: '关于'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: '关于 Hermes',
            subtitle: '版本 1.0.0',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: '用户协议',
            subtitle: '',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: '隐私政策',
            subtitle: '',
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2A2A2A),
                    title: const Text(
                      '退出登录',
                      style: TextStyle(color: Color(0xFFECECEC)),
                    ),
                    content: const Text(
                      '确定要退出登录吗？',
                      style: TextStyle(color: Color(0xFFECECEC)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('退出', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('退出登录'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '应用设置',
              style: TextStyle(
                color: Color(0xFFECECEC),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.dark_mode, color: Color(0xFF5856D6)),
              title: const Text('深色主题', style: TextStyle(color: Color(0xFFECECEC))),
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeColor: const Color(0xFF5856D6),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up, color: Color(0xFF5856D6)),
              title: const Text('消息提示音', style: TextStyle(color: Color(0xFFECECEC))),
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeColor: const Color(0xFF5856D6),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over, color: Color(0xFF5856D6)),
              title: const Text('自动播放语音', style: TextStyle(color: Color(0xFFECECEC))),
              trailing: Switch(
                value: false,
                onChanged: (_) {},
                activeColor: const Color(0xFF5856D6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          '清除缓存',
          style: TextStyle(color: Color(0xFFECECEC)),
        ),
        content: const Text(
          '确定要清除本地缓存吗？这不会删除服务器上的数据。',
          style: TextStyle(color: Color(0xFFECECEC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('缓存已清除'),
                  backgroundColor: Color(0xFF5856D6),
                ),
              );
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF5856D6).withAlpha(40),
          child: Icon(icon, color: const Color(0xFF5856D6), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFFECECEC)),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12))
            : null,
        trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
        onTap: onTap,
      ),
    );
  }
}
