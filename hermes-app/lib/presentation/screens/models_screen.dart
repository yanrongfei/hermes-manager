import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/api_provider.dart';

final modelsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/hermes/v1/models');
    if (response.data is Map && response.data['data'] != null) {
      return response.data['data'] as List<dynamic>;
    }
    return response.data as List<dynamic>;
  } catch (e) {
    return [];
  }
});

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelsAsync = ref.watch(modelsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('模型', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: modelsAsync.when(
        data: (models) => models.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.model_training_outlined, size: 64, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text(
                      '暂无可用模型',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '添加 Gateway 后显示可用模型',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: models.length,
                itemBuilder: (context, index) {
                  final model = models[index];
                  final id = model['id'] ?? '未知';
                  final displayName = model['display_name'] ?? id;
                  final contextLength = model['context_length'] ?? model['context_window'];

                  return Card(
                    color: const Color(0xFF2A2A2A),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF5856D6),
                        child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(color: Color(0xFFECECEC)),
                      ),
                      subtitle: Text(
                        contextLength != null
                            ? '上下文: ${_formatContext(contextLength)}'
                            : id,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      trailing: Icon(Icons.check_circle_outline, color: Colors.grey[600]),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '无法加载模型列表',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }

  String _formatContext(dynamic length) {
    if (length is int) {
      if (length >= 1000000) {
        return '${(length / 1000000).toStringAsFixed(1)}M';
      }
      if (length >= 1000) {
        return '${(length / 1000).toStringAsFixed(0)}K';
      }
      return length.toString();
    }
    return length.toString();
  }
}
