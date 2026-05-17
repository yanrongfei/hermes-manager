import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/gateway.dart';
import '../../data/providers/gateway_provider.dart';

class GatewaysScreen extends ConsumerStatefulWidget {
  const GatewaysScreen({super.key});

  @override
  ConsumerState<GatewaysScreen> createState() => _GatewaysScreenState();
}

class _GatewaysScreenState extends ConsumerState<GatewaysScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Gateway 管理', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF5856D6),
          labelColor: const Color(0xFF5856D6),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: '管理'),
            Tab(text: '本地'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ManagedGatewaysTab(),
          _LocalGatewaysTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF5856D6),
              onPressed: () => _showAddGatewayDialog(context, ref),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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

class _ManagedGatewaysTab extends ConsumerWidget {
  const _ManagedGatewaysTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gatewaysAsync = ref.watch(gatewaysNotifierProvider);
    final notifier = ref.read(gatewaysNotifierProvider.notifier);

    return gatewaysAsync.when(
      data: (gateways) => RefreshIndicator(
        onRefresh: () => notifier.loadGateways(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _ScanSection(gateways: gateways, notifier: notifier),
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
    );
  }
}

class _LocalGatewaysTab extends ConsumerStatefulWidget {
  const _LocalGatewaysTab();

  @override
  ConsumerState<_LocalGatewaysTab> createState() => _LocalGatewaysTabState();
}

class _LocalGatewaysTabState extends ConsumerState<_LocalGatewaysTab> {
  List<GatewayStatus> _statuses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
  }

  Future<void> _fetchStatuses() async {
    setState(() { _loading = true; _error = null; });
    try {
      final notifier = ref.read(gatewaysNotifierProvider.notifier);
      final statuses = await notifier.fetchGatewayStatus();
      setState(() { _statuses = statuses; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text('加载失败', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _fetchStatuses,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_statuses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text('未发现本地 Gateway', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchStatuses,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _statuses.length,
        itemBuilder: (context, index) {
          final gw = _statuses[index];
          return _LocalGatewayCard(status: gw, onRefresh: _fetchStatuses);
        },
      ),
    );
  }
}

class _LocalGatewayCard extends ConsumerStatefulWidget {
  final GatewayStatus status;
  final VoidCallback onRefresh;

  const _LocalGatewayCard({required this.status, required this.onRefresh});

  @override
  ConsumerState<_LocalGatewayCard> createState() => _LocalGatewayCardState();
}

class _LocalGatewayCardState extends ConsumerState<_LocalGatewayCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.status.running
                      ? const Color(0xFF34C759).withAlpha(40)
                      : Colors.grey.withAlpha(40),
                  child: Icon(
                    Icons.dns,
                    color: widget.status.running ? const Color(0xFF34C759) : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.status.profile,
                        style: const TextStyle(
                          color: Color(0xFFECECEC),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.status.host}:${widget.status.port}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.status.running
                        ? const Color(0xFF34C759).withAlpha(30)
                        : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.status.running ? 'running' : 'stopped',
                    style: TextStyle(
                      color: widget.status.running ? const Color(0xFF34C759) : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.status.pid != null) ...[
              const SizedBox(height: 8),
              Text(
                'PID: ${widget.status.pid}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${widget.status.profile}  ${widget.status.host}:${widget.status.port}  PID: ${widget.status.pid ?? "-"}  状态 ${widget.status.running ? "running" : "stopped"}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const Spacer(),
                if (widget.status.running)
                  TextButton(
                    onPressed: _stopGateway,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF3B30),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text('关闭', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopGateway() async {
    final profile = widget.status.profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('关闭 Gateway', style: TextStyle(color: Color(0xFFECECEC))),
        content: Text('确定要关闭 $profile 吗？', style: const TextStyle(color: Color(0xFFECECEC))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final notifier = ref.read(gatewaysNotifierProvider.notifier);
      final result = await notifier.stopGateway(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '操作完成'),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('关闭失败: $e'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
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