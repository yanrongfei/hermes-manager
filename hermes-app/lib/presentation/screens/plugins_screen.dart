import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/api_provider.dart';

final pluginsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/hermes/plugins');
    return response.data as List<dynamic>;
  } catch (e) {
    return [];
  }
});

class PluginsScreen extends ConsumerWidget {
  const PluginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pluginsAsync = ref.watch(pluginsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Plugins', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: pluginsAsync.when(
        data: (plugins) => plugins.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.extension_outlined, size: 64, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text(
                      '暂无 Plugins',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: plugins.length,
                itemBuilder: (context, index) {
                  final plugin = plugins[index];
                  final name = plugin['name'] ?? plugin['id'] ?? 'Unknown';
                  final enabled = plugin['enabled'] ?? true;

                  return Card(
                    color: const Color(0xFF2A2A2A),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: enabled
                            ? Colors.green.withAlpha(50)
                            : Colors.grey.withAlpha(50),
                        child: Icon(
                          Icons.extension,
                          color: enabled ? Colors.green[300] : Colors.grey[600],
                          size: 20,
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: Color(0xFFECECEC)),
                      ),
                      subtitle: Text(
                        enabled ? '已启用' : '已禁用',
                        style: TextStyle(
                          color: enabled ? Colors.green[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      trailing: Switch(
                        value: enabled,
                        onChanged: (v) {
                          // TODO: Toggle plugin
                        },
                        activeColor: const Color(0xFF5856D6),
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '无法加载 Plugins',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }
}
