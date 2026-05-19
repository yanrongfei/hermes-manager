import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('发现', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: ListView(
        children: [
          const _SectionHeader(title: '连接'),
          _DiscoverTile(
            icon: Icons.dns_outlined,
            title: 'Gateway 管理',
            subtitle: '管理 Hermes 网关连接',
            onTap: () => context.push('/gateways'),
          ),
          _DiscoverTile(
            icon: Icons.smart_toy,
            title: 'Agent 目录',
            subtitle: '浏览可用 AI 助手',
            onTap: () => context.push('/agents'),
          ),
          const SizedBox(height: 8),
          const _SectionHeader(title: 'AI 资源'),
          _DiscoverTile(
            icon: Icons.psychology_outlined,
            title: '技能',
            subtitle: '浏览可用 AI 技能',
            onTap: () => context.push('/skills'),
          ),
          _DiscoverTile(
            icon: Icons.extension_outlined,
            title: '插件',
            subtitle: '管理插件扩展',
            onTap: () => context.push('/plugins'),
          ),
          _DiscoverTile(
            icon: Icons.model_training,
            title: '模型',
            subtitle: '查看可用 AI 模型',
            onTap: () => context.push('/models'),
          ),
          const SizedBox(height: 8),
          const _SectionHeader(title: '工具'),
          _DiscoverTile(
            icon: Icons.schedule,
            title: '定时任务',
            subtitle: '计划自动化任务',
            trailing: const _ComingSoonBadge(),
            onTap: () {},
          ),
          _DiscoverTile(
            icon: Icons.view_kanban_outlined,
            title: '看板',
            subtitle: '任务看板视图',
            trailing: const _ComingSoonBadge(),
            onTap: () {},
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

class _DiscoverTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DiscoverTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
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
          child: Icon(icon, color: const Color(0xFF5856D6), size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFFECECEC), fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey[600]),
        onTap: onTap,
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '即将推出',
        style: TextStyle(color: Colors.grey, fontSize: 11),
      ),
    );
  }
}
