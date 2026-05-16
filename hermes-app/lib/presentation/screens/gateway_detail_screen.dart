import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/gateway.dart';
import '../../data/models/profile.dart';
import '../../data/providers/gateway_provider.dart';
import '../../data/providers/profile_provider.dart';
import 'profile_detail_screen.dart';

class GatewayDetailScreen extends ConsumerWidget {
  final String gatewayId;

  const GatewayDetailScreen({super.key, required this.gatewayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewaysAsync = ref.watch(gatewaysNotifierProvider);
    final gateway = gatewaysAsync.whenOrNull(
      data: (list) => list.where((g) => g.id == gatewayId).firstOrNull,
    );
    final profilesAsync = ref.watch(profilesProvider(gatewayId));
    final notifier = ref.read(gatewaysNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          gateway?.name ?? 'Gateway 详情',
          style: const TextStyle(color: Color(0xFFECECEC)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFECECEC)),
            color: const Color(0xFF2A2A2A),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog(context, ref, gateway);
              } else if (value == 'delete') {
                _showDeleteDialog(context, ref);
              } else if (value == 'test') {
                _testConnection(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'test', child: Row(children: [Icon(Icons.wifi, color: Color(0xFF2AABEE), size: 20), SizedBox(width: 8), Text('测试连接', style: TextStyle(color: Color(0xFFECECEC)))])),
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Color(0xFFECECEC), size: 20), SizedBox(width: 8), Text('编辑', style: TextStyle(color: Color(0xFFECECEC)))])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('删除', style: TextStyle(color: Colors.red))])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Gateway info card
          if (gateway != null) _GatewayInfoCard(gateway: gateway, notifier: notifier),
          // Profiles list
          Expanded(
            child: profilesAsync.when(
              data: (profiles) => profiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_outlined, size: 48, color: Colors.grey[700]),
                          const SizedBox(height: 12),
                          Text('暂无 Profile', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                          const SizedBox(height: 8),
                          Text('点击「同步」从网关拉取', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => notifier.syncGateway(gatewayId),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: profiles.length,
                        itemBuilder: (context, index) => _ProfileCard(profile: profiles[index]),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 12),
                    Text('加载失败', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _testConnection(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(gatewaysNotifierProvider.notifier);
    final online = await notifier.testGateway(gatewayId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(online ? '连接成功' : '连接失败'), backgroundColor: online ? const Color(0xFF34C759) : const Color(0xFFFF3B30)),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('确认删除', style: TextStyle(color: Color(0xFFECECEC))),
        content: const Text('删除后无法恢复，且该 Gateway 下的所有 Profile 和 Agent 将一并移除。', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: Colors.grey[500]))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(gatewaysNotifierProvider.notifier).deleteGateway(gatewayId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Gateway? gateway) {
    final nameController = TextEditingController(text: gateway?.name);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('编辑 Gateway', style: TextStyle(color: Color(0xFFECECEC), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(
              controller: nameController,
              style: const TextStyle(color: Color(0xFFECECEC)),
              decoration: InputDecoration(
                labelText: '名称',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true, fillColor: const Color(0xFF343541),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5856D6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await ref.read(gatewaysNotifierProvider.notifier).updateGateway(
                    gatewayId,
                    name: nameController.text.isNotEmpty ? nameController.text.trim() : null,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('保存', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GatewayInfoCard extends StatelessWidget {
  final Gateway gateway;
  final GatewaysNotifier notifier;

  const _GatewayInfoCard({required this.gateway, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('地址: ', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                Expanded(child: Text(gateway.address, style: const TextStyle(color: Color(0xFFECECEC), fontSize: 13))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('状态: ', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: gateway.isOnline ? const Color(0xFF34C759) : Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(gateway.isOnline ? '在线' : '离线', style: TextStyle(color: gateway.isOnline ? const Color(0xFF34C759) : Colors.grey, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await notifier.syncGateway(gateway.id);
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('同步'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2AABEE), minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;

  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF5856D6).withAlpha(40),
          child: const Icon(Icons.folder, color: Color(0xFF5856D6), size: 20),
        ),
        title: Text(profile.displayName, style: const TextStyle(color: Color(0xFFECECEC))),
        subtitle: Text(
          [
            if (profile.model != null) profile.model,
            '${profile.agentCount} agents',
          ].join(' · '),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileDetailScreen(profileId: profile.id, profileName: profile.displayName)),
        ),
      ),
    );
  }
}
