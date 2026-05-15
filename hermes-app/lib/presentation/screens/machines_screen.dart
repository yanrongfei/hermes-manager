import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/machine_provider.dart';

class MachinesScreen extends ConsumerStatefulWidget {
  const MachinesScreen({super.key});

  @override
  ConsumerState<MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends ConsumerState<MachinesScreen> {
  @override
  Widget build(BuildContext context) {
    final machinesAsync = ref.watch(machinesNotifierProvider);
    final notifier = ref.read(machinesNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Gateway 管理', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: machinesAsync.when(
        data: (machines) => RefreshIndicator(
          onRefresh: () => notifier.loadMachines(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Scan section
              _ScanSection(
                machines: machines,
                notifier: notifier,
              ),
              const SizedBox(height: 8),
              // Existing gateways
              if (machines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Icon(Icons.dns_outlined, size: 48, color: Colors.grey[700]),
                      const SizedBox(height: 12),
                      Text(
                        '暂无 Gateway',
                        style: TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击上方「扫描」发现本机 Gateway',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ...machines.map((machine) => Card(
                  color: const Color(0xFF2A2A2A),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF5856D6).withAlpha(40),
                      child: const Icon(Icons.dns, color: Color(0xFF5856D6)),
                    ),
                    title: Text(
                      machine.name ?? machine.address,
                      style: const TextStyle(color: Color(0xFFECECEC)),
                    ),
                    subtitle: Text(
                      machine.address,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MachineDetailScreen(machineId: machine.id),
                      ),
                    ),
                  ),
                )),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 12),
              Text('加载失败', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(machinesNotifierProvider.notifier).loadMachines(),
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
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '添加 Gateway',
                style: TextStyle(
                  color: Color(0xFFECECEC),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: Color(0xFFECECEC)),
                decoration: InputDecoration(
                  labelText: '名称（可选）',
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: const Color(0xFF343541),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
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
                  filled: true,
                  fillColor: const Color(0xFF343541),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入地址';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5856D6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await ref.read(machinesNotifierProvider.notifier).addMachine(
                        addressController.text.trim(),
                        name: nameController.text.isNotEmpty
                            ? nameController.text.trim()
                            : null,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    '添加',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanSection extends StatefulWidget {
  final List machines;
  final MachinesNotifier notifier;

  const _ScanSection({required this.machines, required this.notifier});

  @override
  State<_ScanSection> createState() => _ScanSectionState();
}

class _ScanSectionState extends State<_ScanSection> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    final discovered = widget.notifier.discovered;
    final isScanning = widget.notifier.isScanning;
    final existingAddresses = widget.machines
        .map((m) => m.address)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2AABEE),
              side: const BorderSide(color: Color(0xFF2AABEE), width: 1),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: isScanning
                ? null
                : () async {
                    await widget.notifier.discoverGateways();
                    setState(() => _hasScanned = true);
                  },
            icon: isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2AABEE)),
                  )
                : const Icon(Icons.wifi_tethering, size: 18),
            label: Text(
              isScanning ? '扫描中...' : '扫描本机 Gateway',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ),

        // Discovered results
        if (_hasScanned && !isScanning) ...[
          const SizedBox(height: 12),
          if (discovered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '未发现本机 Gateway，请确保已启动 Gateway 服务',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '发现 ${discovered.length} 个 Gateway',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ),
            ...discovered.map((gw) {
              final alreadyAdded = existingAddresses.contains(gw.address);
              return Card(
                color: const Color(0xFF2A2A2A),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 4, right: 4),
                    decoration: BoxDecoration(
                      color: gw.online ? const Color(0xFF4DCD5E) : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    gw.address,
                    style: const TextStyle(color: Color(0xFFECECEC), fontSize: 14),
                  ),
                  trailing: alreadyAdded
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '已添加',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        )
                      : TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2AABEE),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () async {
                            await widget.notifier.addMachine(gw.address);
                          },
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

class MachineDetailScreen extends ConsumerWidget {
  final String machineId;

  const MachineDetailScreen({super.key, required this.machineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(machineAgentsProvider(machineId));

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Agent 列表', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: agentsAsync.when(
        data: (agents) => agents.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 64, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text(
                      '暂无 Agent',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '从 Gateway 发现可用 Agent',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: agents.length,
                itemBuilder: (context, index) {
                  final agent = agents[index];
                  return Card(
                    color: const Color(0xFF2A2A2A),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF5856D6),
                        child: Text(
                          agent.name.isNotEmpty ? agent.name[0].toUpperCase() : 'A',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        agent.name,
                        style: const TextStyle(color: Color(0xFFECECEC)),
                      ),
                      subtitle: Text(
                        agent.description ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: agent.invited
                          ? const Icon(Icons.group_add, color: Colors.green)
                          : null,
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '错误: $e',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }
}
