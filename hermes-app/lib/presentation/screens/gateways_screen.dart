import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/gateway.dart';
import '../../data/providers/gateway_provider.dart';

class GatewaysScreen extends ConsumerStatefulWidget {
  const GatewaysScreen({super.key});

  @override
  ConsumerState<GatewaysScreen> createState() => _GatewaysScreenState();
}

class _GatewaysScreenState extends ConsumerState<GatewaysScreen> {
  @override
  Widget build(BuildContext context) {
    final gatewaysAsync = ref.watch(gatewaysNotifierProvider);
    final notifier = ref.read(gatewaysNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Gateway 管理', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: gatewaysAsync.when(
        data: (gateways) => RefreshIndicator(
          onRefresh: () => notifier.loadGateways(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _ScanSection(
                gateways: gateways,
                notifier: notifier,
              ),
              const SizedBox(height: 8),
              if (gateways.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.dns_outlined, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text('暂无 Gateway', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('点击上方「扫描」发现 Gateway', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                )
              else
                ...gateways.map((gw) => _GatewayCard(gateway: gw, notifier: notifier)),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 12),
              Text('加载失败，请检查网络', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => notifier.loadGateways(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF5856D6),
        onPressed: () => _showAddGatewayDialog(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddGatewayDialog(BuildContext context, WidgetRef ref) {
    final addressController = TextEditingController();
    final nameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('添加 Gateway', style: TextStyle(color: Color(0xFFECECEC), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFFECECEC)),
                decoration: InputDecoration(
                  labelText: '名称（可选）',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true, fillColor: const Color(0xFF343541),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                style: const TextStyle(color: Color(0xFFECECEC)),
                decoration: InputDecoration(
                  labelText: 'Gateway 地址',
                  hintText: '192.168.1.100:8642',
                  hintStyle: TextStyle(color: Colors.grey[700]),
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true, fillColor: const Color(0xFF343541),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.isEmpty) ? '请输入地址' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: apiKeyController,
                style: const TextStyle(color: Color(0xFFECECEC)),
                decoration: InputDecoration(
                  labelText: 'API Key（可选）',
                  hintStyle: TextStyle(color: Colors.grey[700]),
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
                    if (formKey.currentState!.validate()) {
                      final apiKey = apiKeyController.text.trim();
                      await ref.read(gatewaysNotifierProvider.notifier).addGateway(
                        addressController.text.trim(),
                        name: nameController.text.isNotEmpty ? nameController.text.trim() : null,
                        apiKey: apiKey.isNotEmpty ? apiKey : null,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('添加', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GatewayCard extends StatelessWidget {
  final Gateway gateway;
  final GatewaysNotifier notifier;

  const _GatewayCard({required this.gateway, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF5856D6).withAlpha(40),
                  child: const Icon(Icons.dns, color: Color(0xFF5856D6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gateway.name ?? gateway.address,
                        style: const TextStyle(color: Color(0xFFECECEC), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        gateway.address,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _StatusDot(online: gateway.isOnline),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${gateway.profileCount} profiles · ${gateway.agentCount} agents',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await notifier.syncGateway(gateway.id);
                  },
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2AABEE), minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('同步', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool online;
  const _StatusDot({required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        color: online ? const Color(0xFF34C759) : Colors.grey[600],
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ScanSection extends StatefulWidget {
  final List<Gateway> gateways;
  final GatewaysNotifier notifier;

  const _ScanSection({required this.gateways, required this.notifier});

  @override
  State<_ScanSection> createState() => _ScanSectionState();
}

class _ScanSectionState extends State<_ScanSection> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    final discovered = widget.notifier.discovered;
    final isScanning = widget.notifier.isScanning;
    final existingAddresses = widget.gateways.map((g) => g.address).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2AABEE),
              side: const BorderSide(color: Color(0xFF2AABEE), width: 1),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: isScanning
                ? null
                : () async {
                    await widget.notifier.discoverGateways();
                    setState(() => _hasScanned = true);
                  },
            icon: isScanning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2AABEE)))
                : const Icon(Icons.wifi_tethering, size: 18),
            label: Text(isScanning ? '扫描中...' : '扫描 Gateway', style: const TextStyle(fontSize: 15)),
          ),
        ),
        if (_hasScanned && !isScanning) ...[
          const SizedBox(height: 12),
          if (discovered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('未发现 Gateway，请确保已启动 Gateway 服务', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('发现 ${discovered.length} 个 Gateway', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ),
            ...discovered.map((gw) {
              final alreadyAdded = existingAddresses.contains(gw.address);
              return Card(
                color: const Color(0xFF2A2A2A),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    decoration: BoxDecoration(
                      color: gw.online ? const Color(0xFF34C759) : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    gw.profileName ?? gw.address,
                    style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: gw.model != null
                      ? Text('${gw.model}${gw.provider != null ? ' · ${gw.provider}' : ''}', style: TextStyle(color: Colors.grey[600], fontSize: 11))
                      : null,
                  trailing: alreadyAdded
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(12)),
                          child: const Text('已添加', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        )
                      : TextButton(
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF2AABEE), padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero),
                          onPressed: () => widget.notifier.addDiscoveredGateway(gw),
                          child: const Text('添加', style: TextStyle(fontSize: 13)),
                        ),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }
}
