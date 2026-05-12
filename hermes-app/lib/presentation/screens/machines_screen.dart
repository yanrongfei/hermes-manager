import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/machine_provider.dart';
import 'machine_detail_screen.dart';

class MachinesScreen extends ConsumerWidget {
  const MachinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machinesAsync = ref.watch(machinesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('机器管理')),
      body: machinesAsync.when(
        data: (machines) => machines.isEmpty
            ? const Center(child: Text('暂无机器\n点击右下角添加'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(machinesNotifierProvider.notifier).loadMachines(),
                child: ListView.builder(
                  itemCount: machines.length,
                  itemBuilder: (context, index) {
                    final machine = machines[index];
                    return ListTile(
                      leading: const Icon(Icons.computer),
                      title: Text(machine.name ?? machine.address),
                      subtitle: Text(machine.address),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MachineDetailScreen(machineId: machine.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMachineDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddMachineDialog(BuildContext context, WidgetRef ref) {
    final addressController = TextEditingController();
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加机器'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名称（可选）'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: '地址',
                hintText: '192.168.1.100:8642',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (addressController.text.isNotEmpty) {
                await ref.read(machinesNotifierProvider.notifier).addMachine(
                  addressController.text,
                  name: nameController.text.isNotEmpty ? nameController.text : null,
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
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
      appBar: AppBar(title: const Text('Agent 列表')),
      body: agentsAsync.when(
        data: (agents) => agents.isEmpty
            ? const Center(child: Text('暂无 Agent'))
            : ListView.builder(
                itemCount: agents.length,
                itemBuilder: (context, index) {
                  final agent = agents[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(agent.name[0]),
                    ),
                    title: Text(agent.name),
                    subtitle: Text(agent.description ?? ''),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
